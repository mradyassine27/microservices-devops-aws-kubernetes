#!/bin/bash
set -euo pipefail

# ─── Configuration - à adapter si besoin ───
ACCOUNT_ID="884404665372"
REGION="eu-north-1"
SHA=$(git rev-parse --short HEAD)

# Liste des microservices à builder (dossier src/<nom> dans le repo Google)
SERVICES=(
  "frontend"
  "checkoutservice"
  "currencyservice"
  "paymentservice"
  "productcatalogservice"
  "shippingservice"
)

ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "== Authentification Docker vers ECR =="
aws ecr get-login-password --region "$REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

echo "== SHA utilisé pour tous les tags : $SHA =="

for SERVICE in "${SERVICES[@]}"; do
  echo ""
  echo "======================================"
  echo "== Build de : $SERVICE"
  echo "======================================"

  cd "src/${SERVICE}"

  docker build -t "${SERVICE}:${SHA}" .

  docker tag "${SERVICE}:${SHA}" "${ECR_REGISTRY}/microservices-demo/${SERVICE}:${SHA}"
  docker push "${ECR_REGISTRY}/microservices-demo/${SERVICE}:${SHA}"

  echo "== $SERVICE poussé avec succès : ${ECR_REGISTRY}/microservices-demo/${SERVICE}:${SHA} =="

  cd - > /dev/null
done

echo ""
echo "======================================"
echo "== Toutes les images sont poussées   =="
echo "== Tag utilisé : $SHA                =="
echo "======================================"
echo ""
echo "N'oublie pas de mettre à jour values.yaml avec ce tag :"
echo "  sed -i \"s/tag: \\\".*\\\"/tag: \\\"${SHA}\\\"/g\" values.yaml"
