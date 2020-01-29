#!/usr/bin/env bash
set -e

source ci/scripts/common-func.sh

REQUIRED_ENV_VARS=(
  HOSTNAME
  GENERATED_NAMESPACE
)

export_keyval_env

check_skip_testing_condition

check_req_env_vars

setup_kubectl_context

echo "Generating TLS certs and secret"

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
  name: qliksense-elastic-infra-elastic-infra-tls-secret
type: kubernetes.io/tls
data:
  tls.crt: ${crt}
  tls.key: ${key}
  tls.ca: ${ca}

EOF

## Export the values of rootCA and idpConfig to the shared keyval file
idp_config_file="${BASE_PATH}/ci/common/values/oidc-idp-config.json"
idpConfig=$(cat ${idp_config_file}) &&

if [ -f "$KEYVAL_FILE" ];then
  # Writing GENERATED_NAMESPACE to the keyval properties file
  echo "IDP_CONFIG=${idpConfig}" >> "$KEYVAL_FILE"
fi
