#!/bin/bash

# test deployment and service name we will use to test
appName="qnginx001"
continue_install=false;
namespace=""
unset preflight_status

print_help() {
    echo "usage: ./preflight.sh [OPTIONS]
   Options:
   -h          Prints help.
   -n string   namespace to use.
   "
}

# accept value for namespace in case we run this script from CLI
while getopts "n:h" opt; do
  case $opt in
    n)
      namespace=$OPTARG
      ;;
    h)
      print_help
      exit 1
      ;;  
    \?)
      # in case we want to abort installation in the event of preflight check failure
      # exit 1 
      ;;
  esac
done

if [[ $namespace == "" ]]; then
    echo "namespace empty, resetting it to default namespace."
    namespace="default"
fi

echo "namespace to use: $namespace"
# replace value of namespace in preflight_checks.yaml
sed -i -e "s/PREFLIGHT_NAMESPACE/$namespace/g" clustertests/preflight_check/preflight_checks.yaml

# create a test deployment and service and then run preflight in this setup
kubectl create deployment $appName --image=nginx -n $namespace && \
kubectl create service clusterip $appName --tcp=80:80 -n $namespace && \
kubectl -n $namespace wait --for=condition=ready pod -l app=$appName --timeout=120s && \
/usr/local/bin/preflight clustertests/preflight_check/preflight_checks.yaml --interactive=false | tee outfile.txt

# optional, will download support_bundle for further inspection.
# this is of little use now, as this will be downloaded into the container running this script.
# we intend to address this feature in future.
echo "Downloading support bundle: "
/usr/local/bin/support-bundle clustertests/preflight_check/preflight_checks.yaml

# infer status of the preflight checks to determine if we should continue with Qliksense installation or not.
preflight_status=$( tail -n 2 outfile.txt )

# cleaning up our setup after running checks.
(kubectl delete deployment $appName -n $namespace) || true
(kubectl delete service $appName -n $namespace) || true
rm outfile.txt

# depending on the status of the checks, we will print an appropriate message and continue with installation.
if [[ "$preflight_status" == *PASS* ]]; then
    echo "Preflight checks have passed."
else
    echo "Preflight checks have failed, please proceed at your own risk..."
    # For now, we will not abort installation if preflight checks fail.
    # exit 1
fi

echo "Installing Qliksense..."