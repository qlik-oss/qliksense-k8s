# All Transformers

The transformers in this directory follow certain patterns so that operator can easily creats patch to enable them.

There should be corresponding secrets/config name as folders name in this directory.

for example `policyDecisionsUri` there is a config with the same name exists.

the folders inside `policyDecisionsUri` are look like this and there is an entry

```console
.
├── kustomization.yaml
└── selectivepatch.yaml
```

every transformers which operator can enable, should have at leaset these two files in it.

There should be only one transformer in each folder, which one transformer is for one config or secret key.
