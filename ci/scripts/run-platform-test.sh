#!/usr/bin/env bash
set -e

source ci/scripts/common-func.sh

REQUIRED_ENV_VARS=(
  TARGET_PLATFORM
  GENERATED_NAMESPACE
  QSEFE_LICENSE
)

export_keyval_env

check_skip_testing_condition

check_req_env_vars

setup_kubectl_context


echo "Running platform test gauge ..."
echo ""

echo "Creating Platform Test PVC"
kubectl apply -f ./ci/${TARGET_PLATFORM}/platform-test-pvc.yaml --namespace ${GENERATED_NAMESPACE}

errno=0
TAG=${TAG:=latest}
kubectl run platform-test --namespace ${GENERATED_NAMESPACE} --overrides=$(yq r -j ./ci/platform-test.yaml) \
    --rm --attach --restart=Never -it \
    --image="qliktech-docker-infrastructure.jfrog.io/platformtest-gauge:$TAG" || errno=$?

echo "Exporting platform test reports"
kubectl run platform-tests-results  --overrides=$(yq r -j ./ci/tests-results.yaml) \
    --restart=Never \
    --image=alpine

echo "Wait until the collect test result pod is ready"
CTR_POD=$(kubectl get pod -l purpose=collect-tests-results -o jsonpath="{.items[0].metadata.name}" | grep platform-tests-results)
kubectl wait --for=condition=Ready pod/${CTR_POD} --timeout=60s

mkdir -p /tmp/platform-test-results
kubectl cp ${GENERATED_NAMESPACE}/platform-tests-results:/platform-test-results /tmp/platform-test-results
tar -zcvf /tmp/platform-test-results.tar -C /tmp/platform-test-results .

if [[ ${errno} -ne 0 ]]; then
  echo "Platform Test Gauge Failed..."
  kubectl delete pod platform-tests-results
  exit 1
fi

kubectl delete pod platform-tests-results

echo ""
echo "Platform Test Finished, status: passed"
