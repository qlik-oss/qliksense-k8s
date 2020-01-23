#!/usr/bin/env bash
set -e

source ci/scripts/common-func.sh

REQUIRED_ENV_VARS=(GENERATED_NAMESPACE)

export_keyval_env

check_skip_testing_condition

check_req_env_vars

setup_kubectl_context

# GENERATED_NAMESPACE is a unique random namespace name (defined in install-namespace.sh)
delete_namespace $GENERATED_NAMESPACE
