#!/usr/bin/env bash
source ci/scripts/common-func.sh

NAMESPACES=()

while IFS= read -r line; do
    NAMESPACES+=( "$line" )
done < <( kubectl get namespace -l app=ci | awk 'match($3,/[0-9]+h/) {print $1}' )

while IFS= read -r line; do
    NAMESPACES+=( "$line" )
done < <( kubectl get namespace -l app=ci | awk 'match($3,/[6-9][0-9]m/) {print $1}' )

while IFS= read -r line; do
    NAMESPACES+=( "$line" )
done < <( kubectl get namespace -l app=ci | awk 'match($3,/[1-9][0-9][0-9]m/) {print $1}' )

for NAMESPACE in "${NAMESPACES[@]}" ; do
    echo "====================="
    echo "Cleaning up $NAMESPACE"
    echo ""

    delete_namespace ${NAMESPACE}

    echo ""
    echo "Done cleaning $NAMESPACE"
    echo "====================="
done