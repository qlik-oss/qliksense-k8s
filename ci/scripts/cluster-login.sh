#!/usr/bin/env bash
set -e

source ci/scripts/common-func.sh

REQUIRED_ENV_VARS=(TARGET_PLATFORM)

export_keyval_env

check_skip_testing_condition

check_req_env_vars

if [ ! -z $TARGET_PLATFORM ]; then
  case $TARGET_PLATFORM in
    azure)
      az login --service-principal -u $AZURE_SERVICE_PRINCIPAL_USER -p $AZURE_SERVICE_PRINCIPAL_PASSWORD --tenant $AZURE_TENANT_ID
      az aks get-credentials --name $TARGET_CLUSTER --resource-group $TARGET_CLUSTER --subscription $AZURE_SUBSCRIPTION_ID
      ;;
    gke)
      echo $GKE_USER_SERVICE_ACCOUNT > serviceAccount.json
      gcloud auth activate-service-account --key-file serviceAccount.json
      gcloud container clusters get-credentials $TARGET_CLUSTER --region $REGION --project $CLOUDSDK_CORE_PROJECT
      ;;
    openshift)
      # https://github.com/qlik-trial/openshift-cluster-aws/blob/master/tools.sh
      ACTION=login /src/tools.sh
      ;;
    eks)
      aws s3api get-object --bucket elastic-charts-ci-eks --key kubeconfig_ci-qsefe-master kubeconfig_ci-qsefe-master
      echo 'export KUBECONFIG="$(pwd)/kubeconfig_ci-qsefe-master"' >> $BASH_ENV
      source $BASH_ENV
      ;;
    *) ;;
  esac
fi
