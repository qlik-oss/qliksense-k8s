# Qlik Sense Enterprise on Kubernetes

- [Qlik Sense Enterprise on Kubernetes](#qlik-sense-enterprise-on-kubernetes)
  - [What is this Repository?](#what-is-this-repository)
  - [Quickstart](#quickstart)
    - [Learning through Examples: Typical Use cases](#learning-through-examples-typical-use-cases)
      - [Change release name/prefix](#set-release-name)
      - [Specifying replicas](#specifying-replicas)
      - [Setting resource limits](#setting-resource-limits)
      - [Configuring an IDP](#configuring-an-idp)
      - [Adding a custom root CA certificate (for IDP)](#adding-a-custom-root-ca-certificate-for-idp)
      - [Setting a global storage class](#setting-a-global-storage-class)
      - [Setting a global docker image registry](#setting-a-global-docker-image-registry)
      - [Generate a secret from vault](#generate-a-secret-from-vault)
  - [Design Details](#design-details)
    - [Rationale](#rationale)
    - [How manifests are rendered](#how-manifests-are-rendered)
      - [Components](#components)

## What is this Repository?

This repository contains a filesystem structure that allows for the rendering of QSEoK manifests using the [qlik-oss version](https://github.com/qlik-oss/kustomize/releases) 
of [`kustomize`](https://kustomize.io/). `kustomize` is used to perform "last mile" modifications to component helm charts rendered using `helm template` to provide a 
configuration interface using change fragments (patches) of kubernetes resources using label selectors.

Generally, performing configuration for Qlik Sense is done through the CLI and associated operators, this repository is what is used by those components as the initial state of the cluster prior to configuration. Manual creation of patches in this repository directly is meant for advanced configuarations not handled by the operator.


## Quickstart

By cloning this repository or downloading and unpacking an archive from the releases page you can render a QSEoK manifest for a given profile (current only Docker Desktop is supported).
To render a manifest for a Docker Desktop kubernetes QSEoK cluster instance:

1. Download [`kustomize`](https://kustomize.io/) from [qlik-oss](https://github.com/qlik-oss/kustomize/releases) and put it in your `PATH`. (This is a convienient pre-built version of `kustomize` with all the necessary plugins compiled into it)
2. ~~Download [`gomplate`](https://github.com/hairyhenderson/gomplate/releases/) for your platform and put it in your `PATH`~~ **No Longer Necessary**
3. ~~Download [`helm`](https://github.com/helm/helm/releases/tag/v2.16.1) v2.x latest and put it in your `PATH`~~ **No Longer Necessary**
4. Set an environment variable for a resource decryption key:
   - Bash:
     - `export EJSON_KEY=a8dc748390aac1c60c434d52f32ffb3c37870153d34ace6f526bf1f9d987439d`
   - PowerShell:
     - `$Env:EJSON_KEY="a8dc748390aac1c60c434d52f32ffb3c37870153d34ace6f526bf1f9d987439d"`
5. Navigate into the `qliksense-k8s` directory and execute `kustomize build manifests/docker-desktop`

While you can apply this manifest to your local desktop cluster, the `engine` pods will likely fail as the EULA needs to be explictely accepted.
To do this, you need to patch the engine ConfigMap resource directly that contains this setting using a `kustomize` custom resource (`SelectivePatch`) that contains the patch:

1. Create a file called `acceptEULA.yaml` with that content, place it into the `configuration/patches` directory.
   - _Bash_
     ```yaml
     bash# pushd .
     bash# cd configuration/patches 
     bash# cat <<EOT >> acceptEULA.yaml
     apiVersion: qlik.com/v1
     kind: SelectivePatch
     metadata:
       name: acceptEULA
     enabled: true
     patches:
     - patch: |-
         apiVersion: v1
         kind: ConfigMap
         metadata:
           name: engine-configs
         data:
           acceptEULA: 'yes'
     EOT
     bash# kustomize edit add resource acceptEULA.yaml
     bash# popd
     ```
   - _PowerShell_
     ```yaml
     PS> Push-Location
     PS> Set-Location configuration\patches
     PS> Add-Content -Value @"
     apiVersion: qlik.com/v1
     kind: SelectivePatch
     metadata:
       name: acceptEULA
     enabled: true
     patches:
     - patch: |-
         apiVersion: v1
         kind: ConfigMap
           metadata:
             name: engine-configs
         data:
           acceptEULA: 'yes'
     "@ -Path .\acceptEULA.yaml
     PS> kustomize edit add resource acceptEULA.yaml
     PS> Pop-Location
     ```

2. Navigate into the `qliksense-k8s` directory and execute `kustomize build manifests/docker-desktop`, you can also apply the manifest to a cluster using `kustomize build manifests/docker-desktop | kubectl apply -f - `

### Learning through Examples: Typical Use cases

#### Set release name

By default the generated kubernetes resources are prefixed with `qliksense` which is basically a release name. To change the release name place a patch into `configuration/transformers` folder and add that file name into `configuration/transformers/kustomization.yaml` file. To change the release name to `myrelease` the file content should be like this

```yaml
bash# pushd .
bash# cd configuration/transformers
base# cat <<EOF>> my-release.yaml
apiVersion: qlik.com/v1
kind: SelectivePatch
metadata:
  name: release-template
enabled: true
patches:
- target:
    name: release
    kind: LabelTransformer
  patch: |-
    apiVersion: builtin
    kind: LabelTransformer
    metadata:
      name: release
    labels:
      release: myrelease
EOF

bash# cat <<EOF>> kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- my-release.yaml

EOF
```

#### Specifying replicas

(Examples will use base, for Windows PowerShell, use the same scripting patterns as the quickstart above)

It is possible to specify replicas for resources based on label selectors. For example to specify 3 replicas for all deployments. 
Create a file called `relicas.yaml` with that content, place it into the `configuration/patches` directory. This file contains a 
```yaml
bash# pushd .
bash# cd configuration/patches 
bash# cat <<EOT >> replicas.yaml
apiVersion: qlik.com/v1
kind: SelectivePatch
metadata:
  name: replicas
enabled: true
patches:
- target:
    kind: Deployment
  patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: notneeded
    spec:
      replicas: 3
EOT
bash# kustomize edit add resource relicas.yaml
bash# popd
 ```
Notice that what is specified in `target` indicates a "target" and takes precendence over that which is specified `metadata.name` of the patch.
In this case, it means "Apply the following patch to all targets where `kind` is `Deployment`".

We  may want to be more specific for the replicas of the `audit` component, in which case we would replace the corresponding section above with:
```yaml
patches:
- target:
    kind: Deployment
    labelSelector: app=audit
  patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: notneeded
    spec:
      replicas: 3
```
An alternate version, is to allow the patch to indiciate the target via it's ond group-version-kind (GVK) data and `name` (used when there is no `target`).
```yaml
patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: audit
    spec:
      replicas: 3
```
It is also possible to use a [JSON 6902 patch](http://jsonpatch.com/). This always requires a target as the patch never containss GVK or name data.
```yaml
patches:
- target:
    kind: Deployment
    labelSelector: app=audit
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 3
```
or, more simply
```yaml
patches:
- target:
    kind: Deployment
    name: audit
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 3
```
Replicas for all Deployments except audit and collections
```yaml
patches:
- target:
    kind: Deployment
    labelSelector: "app notin (audit,collections)"
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 3
```
Replicas for all Deployments except audit and collections
```yaml
patches:
- target:
    kind: Deployment
    labelSelector: "app notin (audit,collections)"
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 3
```

#### Setting resource limits

By default, qseok, does not come with any resource limits defined. To create a limit for collections and audit:
```yaml
patches:
- target:
    kind: Deployment
    labelSelector: "app in (audit,collections)"
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: component
    spec:
      template:
        spec:
          containers:
            - name: main
              resources: 
                limits:
                  memory: 512Mi
                requests:
                  cpu: 100m
                  memory: 128Mi
```
In the same way as replicas is used, coll

#### Configuring an IDP
For General documentation on configing IDPs on QSEoK go to Qlik Sense Help.

When configuring any IDP, it requires the following JSON file per IDP:
```json
{
  "claimsMapping": {
    "name": "name",
    "sub": [
        "sub",
        "client_id"
    ]
  },
  "clientId": "foo",
  "clientSecret": "bar",
  "hostname": "elastic.example",
  "issuerConfig": {
    "authorization_endpoint": "http://elastic.example:32123/auth",
    "end_session_endpoint": "http://elastic.example:32123/session/end",
    "introspection_endpoint": "http://elastic.example:32123/token/introspection",
    "issuer": "http://simple-oidc-provider",
    "jwks_uri": "http://elastic.example:32123/certs",
    "token_endpoint": "http://elastic.example:32123/token",
    "userinfo_endpoint": "http://elastic.example:32123/me"
  },
  "postLogoutRedirectUri": "http://elastic.example",
  "realm": "simple"
}
```
The simplest way to patch this configuration into the identify services is to supply it to the indentity providers service
secret (where it is stored) as string data:

```yaml
patches:
- patch: |-
    apiVersion: v1
    kind:Secret
    metadata:
      name: identity-providers-secrets
    stringData:
      idpConfigs: |-
        [ {
            "claimsMapping": {
              "name": "name",
              "sub": [
                  "sub",
                  "client_id"
              ]
            },
            "clientId": "foo",
            "clientSecret": "bar",
            "hostname": "elastic.example",
            "issuerConfig": {
              "authorization_endpoint": "http://elastic.example:32123/auth",
              "end_session_endpoint": "http://elastic.example:32123/session/end",
              "introspection_endpoint": "http://elastic.example:32123/token/introspection",
              "issuer": "http://simple-oidc-provider",
              "jwks_uri": "http://elastic.example:32123/certs",
              "token_endpoint": "http://elastic.example:32123/token",
              "userinfo_endpoint": "http://elastic.example:32123/me"
            },
            "postLogoutRedirectUri": "http://elastic.example",
            "realm": "simple"
          }
        ]
```
As what is being patched is a secret it is also possible to supply the value for idpConfigs as base64 in the `data:`
section.

See [below](#generate-a-secret-from-vault) for an example of how
to pull the IDP configuration secret from vault!

#### Adding a custom root CA certificate (for IDP)

#### Setting a global storage class

#### Setting a global docker image registry

#### Generate a secret from vault

The [`kustomize`](https://kustomize.io/) version from [qlik-oss](https://github.com/qlik-oss/kustomize/releases) has a builtin `gomplate` plugin that allows secrets to be pulled from vault.
You should hav downloaded [`gomplate`](https://github.com/hairyhenderson/gomplate/releases/) an put it you path as part of the "quickstart" above.

As we are using Vault, we will need a vault address specifying the base in which to find the secret and and address. These environmental variables are set prior to the generation of the manifest through `kustomize build .`:
- Bash:
  - `export VAULT_ADDR=https://127.0.0.1:8200`
  - `export VAULT_TOKEN=a8dc748390aac1c60c434d52f32ffb3c37870153d34ace6f526bf1f9d987439d`
- PowerShell:
  - `$Env:VAULT_ADDR=https://127.0.0.1:8200`
  - `$Env:VAULT_TOKEN="a8dc748390aac1c60c434d52f32ffb3c37870153d34ace6f526bf1f9d987439d"`

To pull a secret from vault, a special type of patch needs to be used. We will use the "Configuring an IDP" example, in which case the folling IDP configuration array is stored in vault:

```json
[ {
    "claimsMapping": {
      "name": "name",
      "sub": [
          "sub",
          "client_id"
      ]
    },
    "clientId": "foo",
    "clientSecret": "bar",
    "hostname": "elastic.example",
    "issuerConfig": {
      "authorization_endpoint": "http://elastic.example:32123/auth",
      "end_session_endpoint": "http://elastic.example:32123/session/end",
      "introspection_endpoint": "http://elastic.example:32123/token/introspection",
      "issuer": "http://simple-oidc-provider",
      "jwks_uri": "http://elastic.example:32123/certs",
      "token_endpoint": "http://elastic.example:32123/token",
      "userinfo_endpoint": "http://elastic.example:32123/me"
    },
    "postLogoutRedirectUri": "http://elastic.example",
    "realm": "simple"
  }
]
```

The patch consists of files (that are added to the patches kustomization.yaml). As this is not a patch on the kubernetes resource API, but rather a patch on a kuztomize custom kind called `SuperSecret` used to generate the kubernetes `Secret` kind, it is specified in a different location: `configuration/secrets`.
Two resources will be created, a gomplate transformer, that instructs `kustomize` to execute gomplate on the resources according to this specification:
```yaml
apiVersion: qlik.com/v1
kind: Gomplate
metadata:
  name: identity-service-vault-secrets
  labels:
    key: gomplate
dataSource:
  vault:
    secretPath: path/to/key/values/with/secret
  
```
And the resource patch itself on the `SuperSecret` type for `identity-providers`:
```yaml
apiVersion: qlik.com/v1
kind: SelectivePatch
metadata:
  name: identity-service-mysecrets
enabled: true
patches:
- target:
    kind: SuperSecret
  patch: |-
    apiVersion: qlik.com/v1
    kind: SuperSecret
    metadata:
      name: identity-providers-secrets
    stringData:
      idpConfigs: |-
        (( (ds "vault").idpConfigs | indent 8 ))
```

These needed now need to be added to kustomize in the appropriate directory:
- _Bash_
  ```yaml
  bash# pushd .
  bash# cd configuration/secrets 
  bash# cat <<EOT >> identity-providers-mysecrets.yaml
  apiVersion: qlik.com/v1
  kind: SelectivePatch
  metadata:
    name: identity-providers-secrets
  enabled: true
  patches:
  - target:
      kind: SuperSecret
    patch: |-
      apiVersion: qlik.com/v1
      kind: SuperSecret
      metadata:
        name: identity-providers-secrets
      stringData:
        idpConfigs: |-
          (( (ds "vault").idpConfigs | indent 8 ))
  EOT
  bash# kustomize edit add resource identity-providers-mysecrets.yaml
  bash# cat <<EOT >> identity-providers-vault-secrets.yaml
  apiVersion: qlik.com/v1
  kind: Gomplate
  metadata:
    name: identity-providers-vault-secrets
  dataSource:
    vault:
      secretPath: path/to/key/values/with/secret
  EOT
  bash# cat <<EOT >> kustomization.yaml
  transformers:
  - identity-providers-vault-secrets.yaml
  EOT
  bash# popd
  ```
- _PowerShell_
  ```yaml
  PS> Push-Location
  PS> Set-Location configuration\secrets
  PS> Add-Content -Value @" 
  apiVersion: qlik.com/v1
  kind: SelectivePatch
  metadata:
    name:  identity-providers-secrets
  enabled: true
  patches:
  - target:
      kind: SuperSecret
    patch: |-
      apiVersion: qlik.com/v1
      kind: SuperSecret
      metadata:
        name: identity-providers-secrets
      stringData:
        idpConfigs: |-
          (( (ds "vault").idpConfigs | indent 8 ))
  "@ -Path .\identity-providers-mysecrets.yaml
  PS> kustomize edit add resource identity-providers-mysecrets.yaml
  PS> Add-Content -Value @"
  apiVersion: qlik.com/v1
  kind: Gomplate
  metadata:
    name:  identity-providers-vault-secrets
    labels:
      key: gomplate
  dataSource:
    vault:
      secretPath: path/to/key/values/with/secret
  "@ -Path .\ identity-providers-vault-secrets.yaml
  PS> Add-Content -Value @"
  transformers:
  -  identity-providers-vault-secrets.yaml
  "@ -Path .\kustomization.yaml
  PS> Pop-Location
  ```

Generating the manifest should now also pull the IDP configuration from vault.

This method can be used for any secret or configs. In the case of configs, the resources types is
`SuperConfigMap` for the `kustomize` kind and use the `-configs` postfix for resource names.

## Design Details

### Rationale

As a platform, QSEoK needs to:
a) provide a consistent kubernetes resource layout that allows for higher order operations across all components;
  - Ex. Set a global private registry, use a pvc storage class
b) be able to implement higher order operations without needing to invoke component specific templating logic (consistency);
c) allow for changes to the kubernetes resources so they can be modified directly and not break higher order operations without having to invoke templating logic to export the capability through templating;
  - Ex. Add a side car, provide custom annotation
d) provide an intial cluster state that can be forked in order to provide an intial state for GitOps cluster management;
e) use Git tag versioning as the source of truth for kubernetes infrastucture-as-code releases of QSEoK.
f) decouple configuration logic from service implementation logic

### How manifests are rendered

#### Components

In order to facilate a) (the "Rationale"), components are expected to render are consistent kubernets API. Bespoke components are required to render the required layouts directly from helm using defaults. Off-the-shell
components will be patched immediately from the helm rendering to conform the the required layout.
