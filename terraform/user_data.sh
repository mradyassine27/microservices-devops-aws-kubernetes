#!/bin/bash
set -euxo pipefail

# ─── 1. Préparer le credential provider ECR AVANT d'installer k3s ───
# (le kubelet doit trouver le binaire et le fichier de config dès son premier démarrage)

mkdir -p /etc/kubernetes

cat > /etc/kubernetes/ecr-credential-provider.json <<'EOF'
{
  "apiVersion": "kubelet.config.k8s.io/v1",
  "kind": "CredentialProviderConfig",
  "providers": [
    {
      "name": "ecr-credential-provider",
      "matchImages": [
        "*.dkr.ecr.*.amazonaws.com",
        "*.dkr.ecr.*.amazonaws.com.cn"
      ],
      "defaultCacheDuration": "12h",
      "apiVersion": "credentialprovider.kubelet.k8s.io/v1"
    }
  ]
}
EOF

wget -q https://github.com/dntosas/ecr-credential-provider/releases/download/v1.2.0/ecr-credential-provider-linux-amd64 \
  -O /usr/local/bin/ecr-credential-provider
chmod +x /usr/local/bin/ecr-credential-provider

# ─── 2. Installer k3s, avec les arguments kubelet pour le credential provider dès le départ ───

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --write-kubeconfig-mode 644 \
  --kubelet-arg=image-credential-provider-bin-dir=/usr/local/bin \
  --kubelet-arg=image-credential-provider-config=/etc/kubernetes/ecr-credential-provider.json" sh -

# ─── 3. Attendre que k3s soit prêt ───

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
until kubectl get nodes >/dev/null 2>&1; do
  sleep 5
done

# ─── 4. Installation de Helm ───

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ─── 5. Installation d'ArgoCD ───

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# ─── 6. Prometheus + Grafana ───

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30000