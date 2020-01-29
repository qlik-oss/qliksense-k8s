#!/usr/bin/env bash
set -e

source ci/scripts/common-func.sh

REQUIRED_ENV_VARS=(
  GENERATED_NAMESPACE
  TARGET_PLATFORM
  ROOT_CA
  IDP_CONFIG
)

export_keyval_env

check_skip_testing_condition

check_req_env_vars

setup_kubectl_context

cat <<EOF > cr.tmpl.yaml
configProfile: manifests/docker-desktop
manifestsRoot: "/root/src"
storageClassName: efs
namespace: "$GENERATED_NAMESPACE"
storageClassName: "efs"
rotateKeys: "None"
configs:
- dataKey: acceptEULA
  values:
    qliksense: "yes"
secrets:
- secretKey: mongoDbUri
  values:
    qliksense: mongodb://qliksense-mongodb:27017/qliksense?ssl=false
- secretKey: caCertificate
  values:
    qliksense: ROOT_CA
- secretKey: idpConfigs
  values:
    identity-providers: IDP_CONFIG
EOF


yq w -i -- cr.tmpl.yaml 'secrets[1].values.qliksense' "$ROOT_CA"
yq w -i -- cr.tmpl.yaml 'secrets[2].values.identity-providers' "$IDP_CONFIG"

## Substitute namespace in cr.tmpl.yaml.
cat cr.tmpl.yaml | envsubst > cr.yaml

cat cr.yaml

export YAML_CONF=$(cat cr.yaml)

# Apply patches using operator
qliksense-operator




MANIFEST_DIR="${BASE_PATH}/manifests/docker-desktop"


yq w -i ${BASE_PATH}/manifests/base/transformers/clientCertificates/secret/selectivepatch.yaml 'enabled' true

kustomize build $MANIFEST_DIR | kubectl apply --validate=false -f -
## Apply tls cert needed for nginx ingress cotroller
kubectl apply -f tls-secret.yaml --namespace ${GENERATED_NAMESPACE}

## rollout elastic-infra deployment after creating the new tls secret
ELASTIC_INFRA_POD=$(kubectl get pods -o jsonpath="{.items[*].metadata.name}" -l app=elastic-infra)
kubectl delete pod $ELASTIC_INFRA_POD