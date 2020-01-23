#!/usr/bin/env bash
set -e

source ci/scripts/common-func.sh

REQUIRED_ENV_VARS=(
  GENERATED_NAMESPACE
  CHANGED_CHARTS
)

export_keyval_env

check_skip_testing_condition

check_req_env_vars

setup_kubectl_context

printFailure() {
    step=$1
    chart=$2
    kubectl get pods --namespace $GENERATED_NAMESPACE
    echo ""
    echo "################################"
    echo "  $chart failed to install!"
    echo "  $step"
    echo ""
    echo "################################"
}

testChart() {
    chart=$1
    chartName=$(basename $chart)
    releaseName=`if [ $chartName == "qsefe" ]; then echo sut; else echo sut-${chartName}; fi`
    errno=0
    if [ -f "$chart/requirements.yaml" ]; then
      helm dependency build $chart
    fi
    # load any extraArgs for the helm command if they exist
    extraArgs=""
    # if a common values file template exists, generate a file and add a -f extraArg
    commonValuesFile="ci/common/values/$chartName-values.tmpl.yaml"
    if [ -f $commonValuesFile ]; then
        processedcommonValuesFile=ci/common/values/$chartName-values-generated.yaml
        cat $commonValuesFile | envsubst > $processedcommonValuesFile
        extraArgs="-f $processedcommonValuesFile $extraArgs"
    fi

    # if a target platform values file template exists, generate a file and add a -f extraArg
    targetPlatformValuesFile="ci/$TARGET_PLATFORM/values/$chartName-values.tmpl.yaml"
    if [ -f $targetPlatformValuesFile ]; then
        processedtargetPlatformValuesFile=ci/$TARGET_PLATFORM/values/$chartName-values-generated.yaml
        cat $targetPlatformValuesFile | envsubst > $processedtargetPlatformValuesFile
        extraArgs="-f $processedtargetPlatformValuesFile $extraArgs"
    fi

    if [ "$chartName" = "qliksense-init" ]; then
      echo "Can't helm install qliksense-init in namespace $GENERATED_NAMESPACE"
      exit 0
    fi

    echo "helm install --tiller-namespace="$GENERATED_NAMESPACE" $chart --name $releaseName $extraArgs"
    helm install --tiller-namespace="$GENERATED_NAMESPACE" $chart --name $releaseName $extraArgs || errno=$?
    if [ $errno -ne 0 ]; then
      printFailure "helm install --tiller-namespace="$GENERATED_NAMESPACE"" $chart
      helm delete --tiller-namespace="$GENERATED_NAMESPACE" --purge $releaseName
      return 1
    fi
}

echo "Helm install changed charts..."
failedCharts=""
echo $CHANGED_CHARTS | tr '|' '\n' > ~/.changed-charts
for dir in $(< ~/.changed-charts); do
    errno=0
    testChart "${dir}" || errno=$?
    if [ $errno -ne 0 ]; then
        failedCharts="$failedCharts\n$dir"
    fi
done

if [ -n "$failedCharts" ]; then
  echo "##############################"
  echo ""
  echo " Failed Charts!"
  echo ""
  echo "##############################"
  echo -e "$failedCharts"
  echo ""
  echo "##############################"
  echo ""
  exit 1
fi
