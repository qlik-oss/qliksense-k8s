#!/bin/bash
# You need:
# - kubectl w/ qliksense plugin installed
# - gcloud set to your project: gcloud config set project my-project
# - you may wish to change the zone/region closer to 

echo "What version of QLik Sense?"
read QLIKSENSE_VERSION
echo "What is the DNS domain name of Qlik Sense?"
read DOMAIN
echo "What is the instance/host name of Qlik Sense?"
read QLIKSENSE_HOST
echo "What is the realm/host name of Keycloak?"
read KEYCLOAK_HOST
echo "What is the Keycloak client secret?"
read KEYCLOAK_SECRET
echo "What is the Default Password for Demo Users?"
read DEFAULT_USER_PASSWORD
echo "What will be the Keycloak admin password?"
read KEYCLOAK_ADMIN_PASSWORD

start=`date +%s`
# Create Cluster
gcloud container clusters create $QLIKSENSE_HOST --zone "northamerica-northeast1-a" --no-enable-basic-auth --cluster-version "1.15.9-gke.24" --machine-type "n1-standard-16" --image-type "UBUNTU" --disk-type "pd-standard" --disk-size "100" --metadata disable-legacy-endpoints=true --num-nodes "4" --enable-stackdriver-kubernetes --enable-ip-alias --default-max-pods-per-node "110" --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing --enable-autoupgrade --enable-autorepair
echo "Cluster"
echo "--"
echo "Cluster: $QLIKSENSE_HOST"

# Create Address
gcloud compute addresses create $QLIKSENSE_HOST-ip --region=northamerica-northeast1
gcloud compute addresses create $KEYCLOAK_HOST-ip --global

# IPs
QLIKSENSE_IP=$(gcloud compute addresses describe $QLIKSENSE_HOST-ip --region=northamerica-northeast1 --format='value(address)')
KEYCLOAK_IP=$(gcloud compute addresses describe $KEYCLOAK_HOST-ip --global --format='value(address)')

echo "Addresses"
echo "--"
echo "Qliksense Host: $QLIKSENSE_HOST"
echo "Qliksense IP: $QLIKSENSE_IP"
echo "Keycloak Host: $KEYCLOAK_HOST"
echo "Keycloak IP: $KEYCLOAK_IP"

# DNS
gcloud dns record-sets transaction start --zone=qseok
gcloud dns record-sets transaction add $KEYCLOAK_IP --name=$KEYCLOAK_HOST.$DOMAIN. --ttl=300 --type=A --zone=qseok
gcloud dns record-sets transaction add $QLIKSENSE_IP --name=$QLIKSENSE_HOST.$DOMAIN. --ttl=300 --type=A --zone=qseok
gcloud dns record-sets transaction execute --zone=qseok

echo "DNS"
echo "--"
echo "Qliksense Name: $QLIKSENSE_HOST.$DOMAIN."
echo "Qliksense IP: $QLIKSENSE_IP"
echo "Keycloak Name: $KEYCLOAK_HOST.$DOMAIN."
echo "Keycloak IP: $KEYCLOAK_IP"

gcloud filestore instances create $QLIKSENSE_HOST --file-share=name="qliksense",capacity=1T --network=name="default" --zone northamerica-northeast1-a
NFS_IP=$(gcloud filestore instances describe $QLIKSENSE_HOST --zone northamerica-northeast1-a --format='value(networks[0].ipAddresses[0])')
echo "Filestore"
echo "--"
echo "nfsShare: /qliksense"
echo "nfsServer: $NFS_IP"

gcloud container clusters get-credentials $QLIKSENSE_HOST --zone northamerica-northeast1-a
end=`date +%s`
echo "gcloud duration: $((($(date +%s)-$start)/60)) minutes"

cat <<EOF >> $QLIKSENSE_HOST.yaml
apiVersion: qlik.com/v1
kind: Qliksense
metadata:
  labels:
    version: $QLIKSENSE_VERSION
  name: $QLIKSENSE_HOST
spec:
  storageClassName: $QLIKSENSE_HOST-nfs-client
  profile: gke-demo
  rotateKeys: "yes"
  configs:
    qliksense:
    - name: acceptEULA
      value: "no"
    gke:
    - name: realmName
      value: $QLIKSENSE_HOST
    - name: idpHostName
      value: $KEYCLOAK_HOST.qseok.tk
    - name: qlikSenseDomain
      value: qseok.tk
    keycloak:
    - name: staticIpName
      value: $KEYCLOAK_HOST-ip
    certificate:
    - name: adminEmailAddress
      value: admin@qseok.tk
    nfs-client-provisioner:
    - name: nfsServer
      value: $NFS_IP
    - name: nfsPath
      value: /qliksense
    elastic-infra:
    - name: qlikSenseIp
      value: $QLIKSENSE_IP
  secrets:
    qliksense:
    - name: mongodbUri
      value: "mongodb://$QLIKSENSE_HOST-mongodb:27017/qsefe?ssl=false"
    gke:
    - name: clientSecret
      value: $KEYCLOAK_SECRET
    keycloak:
    - name: defaultUserPassword
      value: $DEFAULT_USER_PASSWORD
    - name: password
      value: $KEYCLOAK_ADMIN_PASSWORD
EOF
