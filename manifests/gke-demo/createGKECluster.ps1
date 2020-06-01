#!/usr/bin/pwsh
# You need:
# - kubectl w/ qliksense plugin installed
# - gcloud set to your project: gcloud config set project my-project
# - you may wish to change the zone/region closer to you

$QLIKSENSE_VERSION = Read-Host -Prompt "What version of QLik Sense?"
$DOMAIN = Read-Host -Prompt "What is the DNS domain name of Qlik Sense?"
$QLIKSENSE_HOST = Read-Host -Prompt "What is the instance/host name of Qlik Sense?"
$KEYCLOAK_HOST = Read-Host -Prompt "What is the realm/host name of Keycloak?"
$KEYCLOAK_SECRET = Read-Host -Prompt "What is the Keycloak client secret?"
$DEFAULT_USER_PASSWORD = Read-Host -Prompt "What is the Default Password for Demo Users?"
$KEYCLOAK_ADMIN_PASSWORD = Read-Host -Prompt "What will be the Keycloak admin password?"

$measure = Measure-Command {
# Create Cluster
gcloud container clusters create $QLIKSENSE_HOST --zone "northamerica-northeast1-a" --no-enable-basic-auth --cluster-version "1.15.9-gke.24" --machine-type "n1-standard-16" --image-type "UBUNTU" --disk-type "pd-standard" --disk-size "100" --metadata disable-legacy-endpoints=true --num-nodes "4" --enable-stackdriver-kubernetes --enable-ip-alias --default-max-pods-per-node "110" --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing --enable-autoupgrade --enable-autorepair

Write-Host "Cluster"
Write-Host "--"
Write-Host "Cluster: $QLIKSENSE_HOST"

# Create Address
gcloud compute addresses create $QLIKSENSE_HOST-ip --region=northamerica-northeast1
gcloud compute addresses create $KEYCLOAK_HOST-ip --global

# IPs
$QLIKSENSE_IP=(gcloud compute addresses describe $QLIKSENSE_HOST-ip --region=northamerica-northeast1 --format='value(address)')
$KEYCLOAK_IP=(gcloud compute addresses describe $KEYCLOAK_HOST-ip --global --format='value(address)')

Write-Host "Addresses"
Write-Host "--"
Write-Host "Qliksense Host: $QLIKSENSE_HOST"
Write-Host "Qliksense IP: $QLIKSENSE_IP"
Write-Host "Keycloak Host: $KEYCLOAK_HOST"
Write-Host "Keycloak IP: $KEYCLOAK_IP"

# DNS
gcloud dns record-sets transaction start --zone=qseok
gcloud dns record-sets transaction add $KEYCLOAK_IP --name=$KEYCLOAK_HOST.$DOMAIN. --ttl=300 --type=A --zone=qseok
gcloud dns record-sets transaction add $QLIKSENSE_IP --name=$QLIKSENSE_HOST.$DOMAIN. --ttl=300 --type=A --zone=qseok
gcloud dns record-sets transaction execute --zone=qseok

Write-Host "DNS"
Write-Host "--"
Write-Host "Qliksense Name: $QLIKSENSE_HOST.$DOMAIN."
Write-Host "Qliksense IP: $QLIKSENSE_IP"
Write-Host "Keycloak Name: $KEYCLOAK_HOST.$DOMAIN."
Write-Host "Keycloak IP: $KEYCLOAK_IP"

gcloud filestore instances create $QLIKSENSE_HOST --file-share=name="qliksense",capacity=1T --network=name="default" --zone northamerica-northeast1-a
$NFS_IP=(gcloud filestore instances describe $QLIKSENSE_HOST --zone northamerica-northeast1-a --format='value(networks[0].ipAddresses[0])')
Write-Host "Filestore"
Write-Host "--"
Write-Host "nfsShare: /qliksense"
Write-Host "nfsServer: $NFS_IP"

gcloud container clusters get-credentials $QLIKSENSE_HOST --zone northamerica-northeast1-a
}
Write-Host "gcloud duration: $measure.Minutes minutes"

$measure = Measure-Command {
# Base Profile
kubectl qliksense config set-context $QLIKSENSE_HOST 
kubectl qliksense config set storageClassName=$QLIKSENSE_HOST-nfs-client
kubectl qliksense config set-configs qliksense.acceptEULA="yes"
kubectl qliksense config set-secrets qliksense.mongodbUri="mongodb://$QLIKSENSE_HOST-mongodb:27017/qsefe?ssl=false"

#GKE Demo profile
kubectl qliksense config set-configs elastic-infra.qlikSenseIp=$QLIKSENSE_IP
kubectl qliksense config set-configs gke.idpHostName=$KEYCLOAK_HOST.$DOMAIN
kubectl qliksense config set-configs gke.realmName=$QLIKSENSE_HOST
kubectl qliksense config set-configs gke.qlikSenseDomain=$DOMAIN
kubectl qliksense config set-secrets gke.clientSecret=$KEYCLOAK_SECRET
kubectl qliksense config set-configs keycloak.staticIpName=$KEYCLOAK_HOST-ip
kubectl qliksense config set-secrets keycloak.defaultUserPassword=$DEFAULT_USER_PASSWORD
kubectl qliksense config set-secrets keycloak.password=$KEYCLOAK_ADMIN_PASSWORD
kubectl qliksense config set-configs certificate.adminEmailAddress=admin@$DOMAIN
kubectl qliksense config set-configs nfs-client-provisioner.nfsServer=$NFS_IP
kubectl qliksense config set-configs nfs-client-provisioner.nfsPath="/qliksense"

kubectl qliksense fetch $QLIKSENSE_VERSION

# Install CRDS
kubectl qliksense config set profile=gke-demo
kubectl qliksense crds install --all

# Install Cert-manager, 
# Need to be done seperatly due to timing issue w/ kube-api
# BUG: Errors can be ignored
kubectl qliksense config set profile=gke-demo/manifests/cert-manager
kubectl qliksense install

# Could wait for kubectl --wait.. nah, should be enough time
# Install gke profile
kubectl qliksense config set profile=gke-demo
kubectl qliksense install
}
Write-Host "qliksense duration: $measure.Minutes minutes"
