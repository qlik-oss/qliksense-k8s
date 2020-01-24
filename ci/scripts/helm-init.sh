#!/usr/bin/env bash
set -e

source ci/scripts/common-func.sh

REQUIRED_ENV_VARS=(
   GENERATED_NAMESPACE
   ART_USERNAME
   ART_PASSWORD
)

export_keyval_env

check_skip_testing_condition

check_req_env_vars

# GENERATED_NAMESPACE: unique randomly generated 32-bit namespace name (defined in install-namespace.sh)
helm init --service-account tiller --upgrade --tiller-namespace=$GENERATED_NAMESPACE --replicas 2 --wait
helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com/
