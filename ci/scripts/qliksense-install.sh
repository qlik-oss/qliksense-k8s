#!/usr/bin/env bash
set -e

source ci/scripts/common-func.sh

REQUIRED_ENV_VARS=(
  GENERATED_NAMESPACE
  TARGET_PLATFORM
)

export_keyval_env

check_skip_testing_condition

check_req_env_vars

setup_kubectl_context


cat <<EOF > cr.tmpl.yaml
configProfile: manifests/docker-desktop
manifestsRoot: "/root/src"
storageClassName: efs
namespace: "$GENERATED_NAMESPACE"
storageClassName: "efs"
configs:
- dataKey: acceptEULA
  values:
    qliksense: "yes"
EOF

cat cr.tmpl.yaml | envsubst > cr.yaml

export YAML_CONF=$(cat cr.yaml)


echo $YAML_CONF

qliksense-operator