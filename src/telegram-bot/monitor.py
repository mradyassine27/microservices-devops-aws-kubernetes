#!/usr/bin/env python3
"""
Bot de surveillance des microservices :
- Scanne les événements Kubernetes anormaux (CrashLoopBackOff, OOMKilled, ImagePullBackOff...)
- Scanne les logs récents des pods à la recherche de motifs d'erreur
- Résume les erreurs trouvées via l'API Claude
- Envoie une alerte formatée sur Telegram
"""

import os
import re
import subprocess
import requests

# ─── Configuration, lue depuis les variables d'environnement (Secret Kubernetes) ───
TELEGRAM_TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
TELEGRAM_CHAT_ID = os.environ["TELEGRAM_CHAT_ID"]
GROQ_API_KEY = os.environ["GROQ_API_KEY"]
NAMESPACE = os.environ.get("WATCH_NAMESPACE", "default")

ERROR_PATTERNS = re.compile(r"(ERROR|Exception|panic|Fatal|Traceback)", re.IGNORECASE)


def run_kubectl(args):
    """Exécute une commande kubectl et retourne sa sortie texte."""
    result = subprocess.run(
        ["kubectl", "-n", NAMESPACE] + args,
        capture_output=True, text=True, timeout=30
    )
    return result.stdout


def get_abnormal_events():
    """Récupère les événements Kubernetes anormaux (Warning) récents."""
    output = run_kubectl([
        "get", "events",
        "--field-selector=type=Warning",
        "--sort-by=.lastTimestamp",
        "-o", "custom-columns=REASON:.reason,OBJECT:.involvedObject.name,MESSAGE:.message",
    ])
    lines = [l for l in output.splitlines()[1:] if l.strip()]
    return lines[-10:]  # les 10 derniers événements anormaux


def get_pod_names():
    output = run_kubectl(["get", "pods", "-o", "custom-columns=NAME:.metadata.name", "--no-headers"])
    return [l.strip() for l in output.splitlines() if l.strip()]


def get_error_logs_for_pod(pod_name, tail=50):
    """Récupère les dernières lignes de logs d'un pod, filtrées sur des motifs d'erreur."""
    output = run_kubectl(["logs", pod_name, "--tail", str(tail)])
    error_lines = [line for line in output.splitlines() if ERROR_PATTERNS.search(line)]
    return error_lines


def summarize_with_groq(raw_text):
    """Envoie les logs Kubernetes à Groq pour générer un résumé."""

    response = requests.post(
        "https://api.groq.com/openai/v1/chat/completions",
        headers={
            "Authorization": f"Bearer {GROQ_API_KEY}",
            "Content-Type": "application/json",
        },
        json={
            "model": "openai/gpt-oss-20b",
            "messages": [
                {
                    "role": "user",
                    "content": (
                        "Voici des logs d'erreur et événements Kubernetes bruts "
                        "d'un cluster hébergeant des microservices. "
                        "Résume en français, en 3-5 lignes maximum : "
                        "quel service est concerné, quelle est probablement la cause, "
                        "et le niveau de gravité (faible/moyen/critique).\n\n"
                        f"{raw_text}"
                    ),
                }
            ],
            "max_tokens": 300,
        },
        timeout=30,
    )

    response.raise_for_status()

    data = response.json()

    return data["choices"][0]["message"]["content"]


def send_telegram_message(text):
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
    requests.post(url, json={
        "chat_id": TELEGRAM_CHAT_ID,
        "text": text,
        "parse_mode": "Markdown",
    }, timeout=15)


def main():
    events = get_abnormal_events()
    error_logs = []

    for pod in get_pod_names():
        errors = get_error_logs_for_pod(pod)
        if errors:
            error_logs.append(f"--- {pod} ---\n" + "\n".join(errors[-5:]))

    if not events and not error_logs:
        print("Aucune anomalie détectée, rien à signaler.")
        return

    raw_report = ""
    if events:
        raw_report += "Événements Kubernetes anormaux :\n" + "\n".join(events) + "\n\n"
    if error_logs:
        raw_report += "Logs d'erreur détectés :\n" + "\n\n".join(error_logs)

    print("Anomalies détectées, envoi à Groq pour résumé...")
    summary = summarize_with_groq(raw_report)

    message = f"⚠️ *Alerte cluster microservices-demo*\n\n{summary}"
    send_telegram_message(message)
    print("Alerte envoyée sur Telegram.")


if __name__ == "__main__":
    main()