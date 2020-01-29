#!/usr/bin/env bash
set -e

source ci/scripts/common-func.sh

REQUIRED_ENV_VARS=(
  GENERATED_NAMESPACE
)

export_keyval_env

check_skip_testing_condition

check_req_env_vars

setup_kubectl_context

echo "Create QSEFE License"
secretName=qsefe-license
kubectl create secret generic ${secretName} --from-literal=qsefe-license=${QSEFE_LICENSE}

echo "Installing simple oidc chart"
errno=0
chartName=simple-oidc-chart
oidcValuesFile="ci/common/values/${chartName}-values.yaml"
for i in {1..5}; do helm install --tiller-namespace="$GENERATED_NAMESPACE" --wait --name qliksense-${chartName} qlik/${chartName} -f ${oidcValuesFile} && errno=0 && break || errno=$? && sleep 30; done;
if [[ ${errno} -ne 0 ]]; then
  echo "ERROR: Failure to install ${chartName} chart"
  exit 1
fi

## Turn off default simple-oidc in edge-auth
yq w -i /root/src/manifests/base/resources/edge-auth/generators/values.yaml 'values.service.type' ClusterIP
yq w -i /root/src/manifests/base/resources/edge-auth/generators/values.yaml 'values.oidc.enabled' false
# Delete the patch for oidc
yq d -i /root/src/manifests/base/resources/edge-auth/patches/deployment.yaml 'spec.template.spec.containers[1]'