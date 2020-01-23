#!/usr/bin/env bash
set -e

source ci/scripts/common-func.sh

REQUIRED_ENV_VARS=(
  HOSTNAME
  GENERATED_NAMESPACE
  TARGET_PLATFORM
)

export_keyval_env

check_skip_testing_condition

check_req_env_vars

setup_kubectl_context

echo "Generating TLS certs and secret"
## HOSTNAME="sut-nginx-ingress-controller"

# Generate root CA
openssl genrsa -out rootCA.key 4096
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1024 -subj "/C=CA/ST=ON/O=Qlik./CN=example" -out rootCA.crt

# Generate ingress certs
openssl genrsa -out $HOSTNAME.key 2048
openssl req -new -sha256 -key $HOSTNAME.key -subj "/C=CA/ST=ON/O=Qlik./CN=$HOSTNAME" -reqexts SAN -config <(cat /etc/ssl/openssl.cnf <(printf "[SAN]\nsubjectAltName=DNS:$HOSTNAME")) -out $HOSTNAME.csr
openssl x509 -req -in $HOSTNAME.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out $HOSTNAME.crt -days 500 -sha256
crt=$(cat $HOSTNAME.crt | base64 | tr -d '\n')
key=$(cat $HOSTNAME.key | base64 | tr -d '\n')
ca=$(cat rootCA.crt | base64 | tr -d '\n')

cat <<EOF > tls-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ci-certificate
type: kubernetes.io/tls
data:
  tls.crt: ${crt}
  tls.key: ${key}
  tls.ca: ${ca}

EOF

kubectl apply -f tls-secret.yaml --namespace ${GENERATED_NAMESPACE}

echo "Create QSEFE License"
secretName=qsefe-license
kubectl create secret generic ${secretName} --from-literal=qsefe-license=${QSEFE_LICENSE}

echo "Installing simple oidc chart"
errno=0
chartName=simple-oidc-chart
oidcValuesFile="ci/common/values/${chartName}-values.yaml"
for i in {1..5}; do helm install --tiller-namespace="$GENERATED_NAMESPACE" --wait --name sut-${chartName} qlik/${chartName} -f ${oidcValuesFile} && errno=0 && break || errno=$? && sleep 30; done;
if [[ ${errno} -ne 0 ]]; then
  echo "ERROR: Failure to install ${chartName} chart"
  exit 1
fi
