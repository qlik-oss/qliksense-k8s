#!/usr/bin/env bash
set -e

source ci/scripts/common-func.sh

REQUIRED_ENV_VARS=(GENERATED_NAMESPACE)

export_keyval_env

check_skip_testing_condition

check_req_env_vars

setup_kubectl_context

mkdir -p /tmp/podlogs

for pod in $(kubectl get pods --namespace $GENERATED_NAMESPACE -o jsonpath="{.items[*].metadata.name}")
do
    for container in $(kubectl get pods $pod --namespace $GENERATED_NAMESPACE -o jsonpath="{.spec.containers[*].name}")
    do
        echo "$pod-$container"
        kubectl logs --limit-bytes=0 --since=24h "$pod" "$container" > /tmp/podlogs/$pod-$container.log || true
    done
done
