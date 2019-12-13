# Qlik Sense Enterprise on Kubernetes

## Installation of Qliksense

- Install Porter from here: https://porter.sh/install/
- Install the followiung Mixins:
  - `porter mixin install kustomize -v 0.2-beta-3-0e19ca4 --url https://github.com/donmstewart/porter-kustomize/releases/download`
  - `porter mixin install qliksense -v v0.9.0 --url https://github.com/qlik-oss/porter-qliksense/releases/download`
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
| rotateKeys | should use existing ejson keys or generate new keys (yes/no)      |    yes |
| scName | storage class name      |    none |

## Service configuration

For information on configuring services to become kubernetes-compatible [refer here](How-to.md)