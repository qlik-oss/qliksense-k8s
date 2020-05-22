#!/bin/bash
# You need:
# - kubectl w/ qliksense plugin installed
# - gcloud set to your project: gcloud config set project my-project
# - you may wish to change the zone/region closer to 

# echo "What version of QLik Sense?"
# read QLIKSENSE_VERSION
# echo "What is the DNS domain name of Qlik Sense?"
# read DOMAIN
echo "What is the instance/host name of Qlik Sense?"
read QLIKSENSE_HOST
# echo "What is the realm/host name of Keycloak?"
# read KEYCLOAK_HOST
# echo "What is the Keycloak client secret?"
# read KEYCLOAK_SECRET
# echo "What is the Default Password for Demo Users?"
# read DEFAULT_USER_PASSWORD
# echo "What will be the Keycloak admin password?"
# read KEYCLOAK_ADMIN_PASSWORD

REGION=us-east-1

start=`date +%s`
# Create Cluster
#***DONE: eksctl create cluster $QLIKSENSE_HOST --nodes 4 --region $REGION

# # Create Address
# gcloud compute addresses create $QLIKSENSE_HOST-ip --region=northamerica-northeast1
# gcloud compute addresses create $KEYCLOAK_HOST-ip --global

# # IPs
# QLIKSENSE_IP=$(gcloud compute addresses describe $QLIKSENSE_HOST-ip --region=northamerica-northeast1 --format='value(address)')
# KEYCLOAK_IP=$(gcloud compute addresses describe $KEYCLOAK_HOST-ip --global --format='value(address)')

# echo "Addresses"
# echo "--"
# echo "Qliksense Host: $QLIKSENSE_HOST"
# echo "Qliksense IP: $QLIKSENSE_IP"
# echo "Keycloak Host: $KEYCLOAK_HOST"
# echo "Keycloak IP: $KEYCLOAK_IP"

# # DNS
# gcloud dns record-sets transaction start --zone=qseok
# gcloud dns record-sets transaction add $KEYCLOAK_IP --name=$KEYCLOAK_HOST.$DOMAIN. --ttl=300 --type=A --zone=qseok
# gcloud dns record-sets transaction add $QLIKSENSE_IP --name=$QLIKSENSE_HOST.$DOMAIN. --ttl=300 --type=A --zone=qseok
# gcloud dns record-sets transaction execute --zone=qseok

# echo "DNS"
# echo "--"
# echo "Qliksense Name: $QLIKSENSE_HOST.$DOMAIN."
# echo "Qliksense IP: $QLIKSENSE_IP"
# echo "Keycloak Name: $KEYCLOAK_HOST.$DOMAIN."
# echo "Keycloak IP: $KEYCLOAK_IP"
ROLE_ARN=$(eksctl get iamidentitymapping --cluster ${QLIKSENSE_HOST} --output json --region $REGION | jq -r '.[0].rolearn')
ROLE_NAME=$(aws iam list-roles | jq  -r --arg ROLE_ARN "$ROLE_ARN" '.[] | .[] | select(.Arn==$ROLE_ARN) | .RoleName')
if [ -z $ROLE_NAME ]
then
  echo "RoleName not found"
  exit 1
fi

#**DONE: aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonElasticFileSystemReadOnlyAccess
#**DONE: EFS_ID=$(aws efs create-file-system --creation-token $QLIKSENSE_HOST-efs --tags Key=Name,Value=$QLIKSENSE_HOST-efs --region $REGION | | jq '.FileSystemId' -r)
EFS_ID=fs-00824c83

SUBNET_IDS=$(aws eks describe-cluster --name $QLIKSENSE_HOST  --region $REGION | jq -r '.cluster.resourcesVpcConfig.subnetIds | .[]')
SECURITY_GROUP_ID=$(aws eks describe-cluster --name $QLIKSENSE_HOST  --region $REGION | jq -r '.cluster.resourcesVpcConfig.securityGroupIds | .[]')

echo "Waiting to finish storage creation"
sleep 60

for subnet in $SUBNET_IDS
do
  echo "Creating mount point for subent: $subnet"
  aws efs create-mount-target --file-system-id $EFS_ID --subnet-id $subnet --security-group $SECURITY_GROUP_ID --region $REGION
done

NODEGROUP_NAME=$(eksctl get nodegroup --cluster $QLIKSENSE_HOST --region $REGION -o json | jq -r '.[]|.Name')

#NODEGROUP_SG=$(aws ec2 describe-security-groups --region $REGION | jq -r --arg NGN  "$NODEGROUP_NAME" '.SecurityGroups | .[] as $parent |$parent.Tags | .[]? | select((.Key=="eksctl.io/v1alpha2/nodegroup-name") and .Value==$NGN) | $parent.GroupId')
NODEGROUP_SG=$(aws ec2 describe-security-groups --region $REGION --filters Name=tag:alpha.eksctl.io/nodegroup-name,Values=$NODEGROUP_NAME | jq -r '.SecurityGroups|.[]|.GroupId')

#CONTROL_SG=$(aws ec2 describe-security-groups --region $REGION | jq -r '.SecurityGroups | .[] | select(.GroupName | contains ("ControlPlaneSecurityGroup")) | .GroupId')

CONTROL_SG=$(aws ec2 describe-security-groups --region $REGION --filters Name=tag:Name,Values=eksctl-$QLIKSENSE_HOST-cluster/ControlPlaneSecurityGroup | jq -r '.SecurityGroups|.[]|.GroupId')

echo "Add NFS Ingress to both $NODEGROUP_SG and $CONTROL_SG vice versa"
aws ec2 authorize-security-group-ingress --group-id $NODEGROUP_SG --protocol tcp --port 2049 --source-group $CONTROL_SG --region $REGION
aws ec2 authorize-security-group-ingress --group-id $CONTROL_SG --protocol tcp --port 2049 --source-group $NODEGROUP_SG --region $REGION


echo "Waiting to finish mounting"
sleep 60


# gcloud filestore instances create $QLIKSENSE_HOST --file-share=name="qliksense",capacity=1T --network=name="default" --zone northamerica-northeast1-a
# NFS_IP=$(gcloud filestore instances describe $QLIKSENSE_HOST --zone northamerica-northeast1-a --format='value(networks[0].ipAddresses[0])')
# echo "Filestore"
# echo "--"
# echo "nfsShare: /qliksense"
# echo "nfsServer: $NFS_IP"

# gcloud container clusters get-credentials $QLIKSENSE_HOST --zone northamerica-northeast1-a
end=`date +%s`
echo "eksctl duration: $((($(date +%s)-$start)/60)) minutes"

cat <<EOF >> $QLIKSENSE_HOST.yaml
apiVersion: qlik.com/v1
kind: Qliksense
metadata:
  labels:
    version: $QLIKSENSE_VERSION
  name: $QLIKSENSE_HOST
spec:
  storageClassName: aws-efs
  profile: eks-demo
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
    efs-provisioner:
    - name: fileSystemId
      value: $EFS_ID
    - name: efsRegion
      value: $REGION
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
EOF
