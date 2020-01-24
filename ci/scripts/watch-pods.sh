#!/usr/bin/env bash
set -e

source ci/scripts/common-func.sh

REQUIRED_ENV_VARS=(GENERATED_NAMESPACE)

export_keyval_env

check_skip_testing_condition

check_req_env_vars

setup_kubectl_context

while true; do
  kubectl get pods --namespace $GENERATED_NAMESPACE || true
  sleep 40
done
