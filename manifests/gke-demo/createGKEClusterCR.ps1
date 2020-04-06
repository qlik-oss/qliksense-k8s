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

Add-Content -Value @"
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
    - name: mongoDbUri
      value: "mongodb://$QLIKSENSE_HOST-mongodb:27017/qsefe?ssl=false"
    gke:
    - name: clientSecret
      value: $KEYCLOAK_SECRET
    keycloak:
    - name: defaultUserPassword
      value: $DEFAULT_USER_PASSWORD
    - name: password
      value: $KEYCLOAK_ADMIN_PASSWORD
"@ -Path .\$QLIKSENSE_HOST.yaml
