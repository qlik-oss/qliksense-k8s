# Qlik Sense Enterprise on Kubernetes

## Installation of Qliksense

- Install Porter from here: https://porter.sh/install/
- Install the followiung Mixins:
  - `porter mixin install kustomize -v 0.2-beta-3-0e19ca4 --url https://github.com/donmstewart/porter-kustomize/releases/download`
  - `porter mixin install qliksense -v v0.14.0 --url https://github.com/qlik-oss/porter-qliksense/releases/download`
- Run Porter build: `porter build -v`
- Ensure connectivity to the target cluster create a kubeconfig credential `porter cred generate`
  - Select `specific value` at the prompt and specify the value. 
  - Select `file path` and specify full path to kube config file ex. `/home/user/.kube/config`
  
- Install the bundle : `porter install --param acceptEULA=yes -c QLIKSENSE`
- Notice `acceptEULA` key has been updated inside `qliksense-configs-<hash>` configMap.

## Generate Credentials from published bundle**

- `porter credential generate demo3 --tag qlik/qliksense-cnab-bundle:v0.1.0`

## Supported Parameters during install

| Name        | Descriptions           | Default  |
| ------------- |:-------------:| -----:|
| profile      | select a profile i.e docker-desktop, aws-eks, gke | docker-desktop |
| acceptEULA      | yes | has to be yes |
| namespace      | any kubernetes namespace      |   default |
| rotateKeys | regenerate application PKI keys on upgrade (yes/no)      |    no |
| scName | storage class name      |    none |

## How To Add Idintity Provider Config

since idp configs are usually mulitline configs it is not conventional to pass to porter duing install as a `param`. Rather put the configs in a file and refer to that file duing `porter install` command. For example to add `keycloak` IDP create file named `idpconfig.txt` and put

```console
idpConfigs=[{"discoveryUrl":"http://keycloak-insecure:8089/keycloak/realms/master22/.well-known/openid-configuration","clientId":"edge-auth","clientSecret":"e15b5075-9399-4b20-a95e-023022aa4aed","realm":"master","hostname":"elastic.example","claimsMapping":{"sub":["sub","client_id"],"name":["name","given_name","family_name","preferred_username"]}}]

```

Then pass that file during install command like this

```console
porter install --param acceptEULA=yes -c QLIKSENSE --param-file idpconfigs.txt
```

## Service configuration

For information on configuring services to become kubernetes-compatible [refer here](How-to.md)
