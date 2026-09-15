#!/usr/bin/env python3
"""
Bot de surveillance des microservices :
- Scanne les événements Kubernetes anormaux
- Scanne les logs récents des pods
- Résume les anomalies via Groq
- Envoie une alerte lisible sur Telegram
"""

import os
import re
import subprocess
import requests


# ─── Configuration ────────────────────────────────────────────────────────────

TELEGRAM_TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
TELEGRAM_CHAT_ID = os.environ["TELEGRAM_CHAT_ID"]
GROQ_API_KEY = os.environ["GROQ_API_KEY"]
NAMESPACE = os.environ.get("WATCH_NAMESPACE", "default")

ERROR_PATTERNS = re.compile(
    r"(ERROR|Exception|panic|Fatal|Traceback)",
    re.IGNORECASE
)


# ─── Kubernetes ───────────────────────────────────────────────────────────────

def run_kubectl(args):
    """Exécute une commande kubectl et retourne sa sortie."""
    result = subprocess.run(
        ["kubectl", "-n", NAMESPACE] + args,
        capture_output=True,
        text=True,
        timeout=30
    )

    if result.returncode != 0:
        print(f"kubectl error: {result.stderr}")
        return ""

    return result.stdout


def get_abnormal_events():
    """Récupère les derniers événements Kubernetes Warning."""
    output = run_kubectl([
        "get", "events",
        "--field-selector=type=Warning",
        "--sort-by=.lastTimestamp",
        "-o",
        "custom-columns=REASON:.reason,OBJECT:.involvedObject.name,MESSAGE:.message",
    ])

    lines = [
        line.strip()
        for line in output.splitlines()[1:]
        if line.strip()
    ]

    return lines[-10:]


def get_pod_names():
    """Récupère les noms des pods."""
    output = run_kubectl([
        "get", "pods",
        "-o",
        "custom-columns=NAME:.metadata.name",
        "--no-headers"
    ])

    return [
        line.strip()
        for line in output.splitlines()
        if line.strip()
    ]


def get_error_logs_for_pod(pod_name, tail=50):
    """Récupère les dernières erreurs des logs d'un pod."""
    output = run_kubectl([
        "logs",
        pod_name,
        "--tail",
        str(tail)
    ])

    return [
        line
        for line in output.splitlines()
        if ERROR_PATTERNS.search(line)
    ]


# ─── Groq ─────────────────────────────────────────────────────────────────────

def summarize_with_groq(raw_text):
    """Analyse les anomalies Kubernetes avec Groq."""

    prompt = f"""
Tu es un expert Kubernetes et DevOps.

Analyse les événements et logs suivants.

Réponds UNIQUEMENT avec un résumé court en français.

Format obligatoire :

Gravité : faible, moyen ou critique

Services touchés :
- service1
- service2

Problème :
Explique brièvement le problème détecté.

Cause probable :
Explique brièvement la cause.

Action recommandée :
Donne une action simple à effectuer.

IMPORTANT :
- Maximum 10 lignes.
- Ne commence pas une phrase ou une liste que tu ne termines pas.
- N'utilise pas de Markdown complexe.
- Ne mets pas de caractères comme *, _, ` ou #.
- Si aucun service n'est clairement identifié, indique "Service non identifié".
- Ne fais pas d'invention.

DONNÉES KUBERNETES :

{raw_text}
"""

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
                    "content": prompt
                }
            ],
            "max_tokens": 250,
            "temperature": 0.2,
        },
        timeout=30,
    )

    response.raise_for_status()

    data = response.json()

    return data["choices"][0]["message"]["content"].strip()


# ─── Telegram ─────────────────────────────────────────────────────────────────

def send_telegram_message(text):
    """Envoie un message Telegram sans Markdown."""

    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"

    # Telegram accepte environ 4096 caractères par message.
    max_length = 4000

    for i in range(0, len(text), max_length):

        chunk = text[i:i + max_length]

        response = requests.post(
            url,
            json={
                "chat_id": TELEGRAM_CHAT_ID,
                "text": chunk,
            },
            timeout=15
        )

        response.raise_for_status()


# ─── Programme principal ──────────────────────────────────────────────────────

def main():

    print("Analyse du cluster Kubernetes...")

    events = get_abnormal_events()

    error_logs = []

    for pod in get_pod_names():

        errors = get_error_logs_for_pod(pod)

        if errors:

            error_logs.append(
                f"--- {pod} ---\n" +
                "\n".join(errors[-5:])
            )

    # ─── Aucune anomalie ──────────────────────────────────────────────────────

    if not events and not error_logs:

        print("Aucune anomalie détectée.")
        return

    # ─── Construction du rapport ─────────────────────────────────────────────

    raw_report = ""

    if events:

        raw_report += (
            "ÉVÉNEMENTS KUBERNETES :\n"
            + "\n".join(events)
            + "\n\n"
        )

    if error_logs:

        raw_report += (
            "LOGS D'ERREUR :\n"
            + "\n\n".join(error_logs)
        )

    print("Anomalies détectées.")
    print("Analyse avec Groq...")

    try:

        summary = summarize_with_groq(raw_report)

    except Exception as e:

        print(f"Erreur Groq : {e}")

        summary = (
            "Une anomalie Kubernetes a été détectée.\n\n"
            "Analyse Groq indisponible."
        )

    # ─── Message Telegram ─────────────────────────────────────────────────────

    message = (
        "⚠️ ALERTE CLUSTER — microservices-demo\n\n"
        + summary
        + "\n\n"
        "🤖 Monitoring Bot"
    )

    print("Message Telegram :")
    print(message)

    send_telegram_message(message)

    print("Alerte envoyée sur Telegram.")


if __name__ == "__main__":
    main()
```
