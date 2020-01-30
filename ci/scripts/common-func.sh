#!/usr/bin/env bash

INDEPENDENT_CHARTS_CI_PIPELINE="elastic-charts-ci-${TARGET_PLATFORM}"
QLIKSENSE_INTEGRATION_CI_PIPELINE="qliksense-integration-ci-${TARGET_PLATFORM}"
SKIP_TESTING_MSG="No changes detected that require tests - skipping with a passing status."

check_req_env_vars () {
  for env_var in "${REQUIRED_ENV_VARS[@]}" ; do
    eval env_var_val=\$${env_var}
    if [[ -z "$env_var_val" ]]; then
        echo "$env_var environment variable must be set"
        exit 1
    fi
  done
}

export_keyval_env () {
  if [ -f "$KEYVAL_FILE" ]
   then
      while IFS= read -r var
      do
        if [[ ! -z "$var" && `echo ${var} | grep -E "SKIP_TESTING|GENERATED_NAMESPACE|CHANGED_CHARTS|QSEFE_INSTALL|ROOT_CA|IDP_CONFIG"` ]]
        then
          export "$var"
        fi
      done < "$KEYVAL_FILE"
  fi
}

setup_kubectl_context () {
  kubectl config set-context $(kubectl config current-context) --namespace=${GENERATED_NAMESPACE}
}

check_skip_testing_condition () {
  if [ ! -z "${SKIP_TESTING}" ]; then
    echo "${SKIP_TESTING}"
    exit 0
  fi
}

delete_namespace () {
  namespace=$1
  errno=0
  kubectl get namespaces | grep -w ${namespace} || errno=$?
  if [[ ${errno} -eq 0 ]]; then
    kubectl delete deployments --all --grace-period=0 --force -n ${namespace}
    kubectl delete statefulset --all --grace-period=0 --force -n ${namespace}
    kubectl delete services --all --grace-period=0 --force -n ${namespace}
    kubectl delete job --all --grace-period=0 --force -n ${namespace}
    kubectl delete pods --all --grace-period=0 --force -n ${namespace}
    kubectl delete pvc --all --grace-period=0 --force -n ${namespace}

    kubectl delete namespace --grace-period=0 --force --wait=false ${namespace}
  else
    echo "$namespace namespace does not exit."
    exit 1
  fi
}
