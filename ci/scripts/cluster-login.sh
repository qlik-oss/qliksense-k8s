#!/usr/bin/env bash
set -e

source ci/scripts/common-func.sh

REQUIRED_ENV_VARS=(TARGET_PLATFORM)

export_keyval_env

check_skip_testing_condition

check_req_env_vars

if [ ! -z $TARGET_PLATFORM ]; then
  case $TARGET_PLATFORM in
    openshift)
      # https://github.com/qlik-trial/openshift-cluster-aws/blob/master/tools.sh
      ACTION=login /src/tools.sh
      ;;
    *) ;;
  esac
fi
