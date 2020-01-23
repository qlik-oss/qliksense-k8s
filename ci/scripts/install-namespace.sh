#!/usr/bin/env bash
set -e

source ci/scripts/common-func.sh

REQUIRED_ENV_VARS=(
  KEYVAL_FILE
  ART_USERNAME
  ART_PASSWORD
)

check_req_env_vars

export_keyval_env

check_skip_testing_condition

# Generate a random 32 bits alphanumeric string
GENERATED_NAMESPACE=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 | tr '[:upper:]' '[:lower:]')
# KEYVAL_FILE is the path for the keyval resource properties file and exported from the concourse job.
if [ -f "$KEYVAL_FILE" ];then
  # Writing GENERATED_NAMESPACE to the keyval properties file
  echo "GENERATED_NAMESPACE=${GENERATED_NAMESPACE}" >> "$KEYVAL_FILE"
fi

cat <<EOF > limitRange.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-qliksense-limit
spec:
  limits:
  - defaultRequest:
      memory: 120Mi
      cpu:  "0.1"
    type: Container
EOF

echo "Creating namespace $GENERATED_NAMESPACE"
kubectl create namespace $GENERATED_NAMESPACE
setup_kubectl_context
kubectl apply -f /rbac/helm-namespace-sa.yaml
kubectl apply -f ./limitRange.yaml

kubectl create secret docker-registry artifactory-registry-secret --docker-server=https://qliktech-docker-snapshot.jfrog.io/v1/ \
    --docker-username=$ART_USERNAME --docker-password=$ART_PASSWORD --docker-email=qlik-efe-reference-dev@qlik.com

kubectl create secret docker-registry artifactory-docker-secret --docker-server=https://qliktech-docker.jfrog.io/v1/ \
    --docker-username=$ART_USERNAME --docker-password=$ART_PASSWORD --docker-email=qlik-efe-reference-dev@qlik.com

kubectl create secret docker-registry artifactory-docker-infrastructure-secret --docker-server=https://qliktech-docker-infrastructure.jfrog.io/v1/ \
    --docker-username=$ART_USERNAME --docker-password=$ART_PASSWORD --docker-email=qlik-efe-reference-dev@qlik.com

kubectl create secret docker-registry artifactory-docker-experimental-secret --docker-server=https://qliktech-docker-experimental.jfrog.io/v1/ \
    --docker-username=$ART_USERNAME --docker-password=$ART_PASSWORD --docker-email=qlik-efe-reference-dev@qlik.com

kubectl label namespace $GENERATED_NAMESPACE app=ci
