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

echo "Running system test"
echo ""

echo "Creating System Test PVC"
kubectl apply -f ./ci/${TARGET_PLATFORM}/system-test-pvc.yaml --namespace ${GENERATED_NAMESPACE}

errno=0
kubectl run system-test --namespace ${GENERATED_NAMESPACE} --overrides=$(yq r -j ./ci/system-test.yaml) \
    --rm --attach --restart=Never -it \
    --image=qliktech-docker-infrastructure.jfrog.io/elastic-system-test || errno=$?

echo "Exporting system test reports"
kubectl run system-tests-results --namespace ${GENERATED_NAMESPACE} --overrides=$(yq r -j ./ci/tests-results.yaml) \
    --restart=Never \
    --image=alpine

echo "Wait until the collect test result pod is ready"
CTR_POD=$(kubectl get pod -l purpose=collect-tests-results -o jsonpath="{.items[0].metadata.name}" | grep system-tests-results)
kubectl wait --for=condition=Ready pod/${CTR_POD} --timeout=60s

mkdir -p /tmp/system-test-reports
kubectl cp ${GENERATED_NAMESPACE}/system-tests-results:/system-test-results /tmp/system-test-reports
tar -zcvf /tmp/system-test-reports.tar -C /tmp/system-test-reports .

if [[ ${errno} -ne 0 ]]; then
  echo "System Test Failed..."
  kubectl delete pod system-tests-results
  exit 1
fi

kubectl delete pod system-tests-results

echo ""
echo "Elastic System Test Finished, status: passed"
