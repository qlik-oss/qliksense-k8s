# GKE Demo for QSEoK

GKE Demo for QSEoK is an opinionated Qlik Sense on Kubernetes (QSEoK) Kubernetes manifest for Google Kubernete Engine (GKE). 

It provides the components and minimal configuration for QSEoK to come up in a readily working state on Google Cloud Platform (GCP) through the use of the qliksense operator.

It uses [Keycloak](https://www.keycloak.org/) as an IDP, [Google Filestore](https://cloud.google.com/filestore) as file storage, Let's Encrypt [cert-manager](https://cert-manager.io/docs/) for qliksense certificates and [Google SSL Certificates](https://cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs) for keycloak (as it is using GCE load balancer for ingress). A Kubernetes-embedded [MongoDB](https://www.mongodb.com/kubernetes) engine is being for document storage.

## Prerequisites and Installation

Before you begin, ensure you have met the following requirements:
<!--- These are just example requirements. Add, duplicate or remove as required --->
* You have a `<Windows/Linux/Mac>` machine.
* You have a Google account with the ability to create clusters, Static IPs, DNS entries and issue Google Managed Certificate requests for Google compute engine (GCE) load balancer
* (Google Cloud SDK)[https://cloud.google.com/sdk/install] installed, authenticated and set to the desired project in GCP
* You have installed the latest version of the qliksense operator found [here](https://github.com/qlik-oss/sense-installer)
  - Convienence script for Linux/Mac bash:
    ```shell
    curl -LOJ https://storage.googleapis.com/kubernetes-release/release/1.15.9/bin/linux/amd64/kubectl
    curl -LOJ https://raw.githubusercontent.com/qlik-oss/qliksense-k8s/master/manifests/gke-demo/createGKECluster.sh
    curl -LOJ https://raw.githubusercontent.com/qlik-oss/qliksense-k8s/master/manifests/gke-demo/createGKEClusterRC.sh
    curl -LOJ https://github.com/qlik-oss/sense-installer/releases/latest/download/qliksense-linux-amd64
    sudo mv qliksense-linux-amd64 kubectl /usr/local/bin
    sudo chmod ugo+x createGKECluster.sh /usr/local/bin/qliksense /usr/local/bin/kubectl
    sudo ln -s /usr/local/bin/qliksense-linux-amd64 /usr/local/bin/qliksense
    sudo ln -s /usr/local/bin/qliksense-linux-amd64 /usr/local/bin/kubectl-qliksense
    ```
   - Convienience script for Windows Powershell, make sure C:\bin is in your path:
     ```shell
     Invoke-WebRequest https://github.com/qlik-oss/sense-installer/releases/latest/download/qliksense-windows-amd64.exe -O C:\bin\qliksense.exe
     Copy-Item C:\bin\qliksense.exe cp C:\bin\kubectl-qliksense.exe
     Invoke-WebRequest https://raw.githubusercontent.com/qlik-oss/qliksense-k8s/master/manifests/gke-demo/createGKECluster.ps1 -O C:\bin\createGKECluster.ps1
    Invoke-WebRequest https://raw.githubusercontent.com/qlik-oss/qliksense-k8s/master/manifests/gke-demo/createGKECluster.ps1 -O C:\bin\createGKEClusterRC.ps1
     ```
  * The following information:
    * A version of this repo (v0.0.8 tested to work)
    * A Domain name (Free ones available [here](https://www.freenom.com/))
    * A choosen hostname for the QSEoK application, and another for Keycloak
    * 3 strong passwords for the 
      * Keycloak Client secret
      * The Keycloak administrator password (username: `keycloak`)
      * Initial passwords for the tenant admin and demo users (to be set at login):
        * The Tenant Administrator (username:  `rootadmin`)
        * Barb Stovin (username: `barb`), Evan Highman (username: `highman`), Franklin Glamart (username: `franklin`), Harley Kiffe (username: `harley`), Marne Probetts (username: `marne`), Peta Sammon (username: `peta`), Phillie Smeed (username: `phillie`), Quinn Leeming (username: `quinn`), Sibylla Meadows (username: `sibylla`), Sim Cleaton (username: `sim`)

## GKE Demo for QSEoK

There are two routes to take, installing QSEoK imperatively or declarivily using a configuration resource.

### Imperative

The `createGKECLuster.sh/ps1` script contains all the command needed to bring up the cluster. Simply run the script and provide the parameters described
in the [Prerequisite](#prerequisites-and-installation) above.

The process will take about 15 minutes in total. Qlik Sense will be available at https://<choose hostname for qseok>.<domain name>/

### Declarative
To install <project_name>:

- Run the `createGKECluster.sh/ps1` script. 
- Provide the parameters described in the [Prerequisite](#prerequisites-and-installation) above.

This should take 5-10 minutes.
The output of the script is a qliksense configuration resource `yaml`, named after the Qlik Sense host name, encoded with all the information collected by the script from the output of `gcloud` commands using the parmameters provided:
Ex:
```yaml
apiVersion: qlik.com/v1
kind: Qliksense
metadata:
  name: qliksense-dev
spec:
  storageClassName: qliksense-dev-nfs-client
  profile: gke-demo
  rotateKeys: "yes"
  configs:
    qliksense:
    - name: acceptEULA
      value: "no"
    gke:
    - name: realmName
      value: qliksense-dev
    - name: idpHostName
      value: keycloak-dev.qseok.tk
    - name: qlikSenseDomain
      value: qseok.tk
    keycloak:
    - name: staticIpName
      value: keycloak-dev-ip
    certificate:
    - name: adminEmailAddress
      value: admin@qseok.tk
    nfs-client-provisioner:
    - name: nfsServer
      value: 111.211.221.222
    - name: nfsPath
      value: /qliksense
    elastic-infra:
    - name: qlikSenseIp
      value: 123.123.123.123
  secrets:
    qliksense:
    - name: mongoDbUri
      value: "mongodb://qliksense-dev-mongodb:27017/qsefe?ssl=false"
    gke:
    - name: clientSecret
      value: somestrongsecret
    keycloak:
    - name: defaultUserPassword
      value: somestrongsecret
    - name: password
      value: somestrongsecret
```

* Take the file and load it into the operator:  
  ```shell
  qliksense load -f qliksense-dev.yaml
  ```
* Fetch a version of Qlik Sense On Kubernetes
  ```shell
  qliksense fetch v0.0.8
  ```
* Install the CRDs (accepting the EULA terms). CRDs need to be installed outside of the main manifest because of timing issues.
  ```shell
  qliksense crds install --all
  ```
* Further, Certificate Manager Controller has a timing issue that prevents it being installed together with an Issuer resource (in the same manifest), so it has to be installed before the manifest which contains it. The qliksense operator allows for partial manifest fragment installation updates of a release. We need to set the global manifest (`gke-demo`) to be specific to  `cert-manager` and install:
  ```shell
  qliksense config set profile=qke-demo/manifests/cert-manager
  qliksense install
  ```
* Now we can proceed with installing the main `gke-demo` profile by setting it back and installing.
  ```shell
  qliksense config set profile=qke-demo
  qliksense install
  ```
  
  This should take an additional 5-10 minutes. Once complete Qlik Sense will be available at https://<choose hostname for qseok>.<domain name>/.

  