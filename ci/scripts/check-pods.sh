#!/usr/bin/env bash
set -e

source ci/scripts/common-func.sh

REQUIRED_ENV_VARS=(GENERATED_NAMESPACE)

export_keyval_env

check_skip_testing_condition

check_req_env_vars

setup_kubectl_context

MAX_RETRY=100
RETRY_DELAY=10

# Ensure all pods in the namespace entered a Running state
POD_RETRY_COUNT=0
PODS_FOUND=0
PODS_STATUS=""
PODS_RUNNING=0

while (("$POD_RETRY_COUNT" < "$MAX_RETRY")); do
  POD_RETRY_COUNT=$((POD_RETRY_COUNT + 1))
  PODS_STATUS=$(kubectl get pods --no-headers --namespace "$NAMESPACE")

  if [[ -z "$PODS_STATUS" ]];then
    echo "INFO: No pods found for this release, retrying after sleep"

    sleep "$RETRY_DELAY"
    continue
  else
    PODS_FOUND=1
  fi

  if ! echo "$PODS_STATUS" | grep -Ev "Running|Completed"; then
    PODS_RUNNING=0
    break
  else
    echo "INFO: Waiting for pods to enter running state"
    PODS_STATUS=$(kubectl get pods --no-headers --namespace "$NAMESPACE")
    echo "$PODS_STATUS" | grep -Ev "Running|Completed"
    PODS_RUNNING=1

    echo "INFO: Sleeping for $RETRY_DELAY"
    sleep "$RETRY_DELAY"
    continue
  fi
done

echo "DEBUG: Done waiting for pods"

if (("$PODS_FOUND" == 0)); then
  echo "WARN: No pods launched by this chart's default settings"
  exit 0
fi

if (("$PODS_RUNNING" == 0)); then
  echo "INFO: All pods entered the Running state"
else
  echo "ERROR: Some containers failed to enter the Running state"
  echo "$PODS_STATUS" | grep -Ev "Running|Completed"
  exit 1
fi

# Ensure all containers in all pods in the namespace entered a Ready state
CONTAINER_RETRY_COUNT=0
READINESS_RETRY_COUNT=0
READINESS_RETRY_DELAY=2
PODS_READY=0

echo "DEBUG: Ensure pods are ready"

while (("$CONTAINER_RETRY_COUNT" < "$MAX_RETRY")); do
  JSON_PATH="{.items[*].status.containerStatuses[?(@.ready!=true)].name}"
  UNREADY_CONTAINERS=$(kubectl get pods --namespace "$NAMESPACE" -o "jsonpath=$JSON_PATH")

  if [[ -n "$UNREADY_CONTAINERS" ]]; then
    echo "INFO: Some containers are not yet ready; retrying after sleep"
    echo $UNREADY_CONTAINERS | tr " " "\n"

    CONTAINER_RETRY_COUNT=$((CONTAINER_RETRY_COUNT + 1))
    READINESS_RETRY_COUNT=0
    PODS_READY=1

    sleep "$RETRY_DELAY"
    continue
  else
    echo "INFO: All containers are ready"
    if (("$READINESS_RETRY_COUNT" < 3)); then
        echo "INFO: Double-checking readiness again"

        READINESS_RETRY_COUNT=$((READINESS_RETRY_COUNT + 1))

        sleep "$READINESS_RETRY_DELAY"
        continue
    fi
    PODS_READY=0
    break
  fi
done

if (("$PODS_READY" == 0)); then
  echo "INFO: All containers are ready"
  kubectl get pods --namespace $GENERATED_NAMESPACE | grep -e "sut-*"
  exit 0
else
  echo "ERROR: Some containers failed to reach the ready state"
  kubectl get pods -n $GENERATED_NAMESPACE -o json  | jq -r '.items[] | select(.status.phase != "Running" or ([ .status.conditions[] | select(.type == "Ready" and .status == "False") ] | length ) == 1 ) | .metadata.name'
  echo ""
  echo "##########################################################"
  echo "Requirements: All pods become ready with the default value"
  echo "###########################################################"
  exit 1
fi