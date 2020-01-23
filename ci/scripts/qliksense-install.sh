#!/usr/bin/env bash
set -e

source ci/scripts/common-func.sh

REQUIRED_ENV_VARS=(
  GENERATED_NAMESPACE
  TARGET_PLATFORM
)

RRS_CONTR_CHARTS=(
  audit
  quotas
)

export_keyval_env

check_skip_testing_condition

check_req_env_vars

setup_kubectl_context



echo "Which directory i'm in"

pwd

ls -la