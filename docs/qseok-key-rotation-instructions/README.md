# qseok-key-rotation-instructions
QSEoK security recommendation to replace default service-to-service keys

Public private key pairs are used to sign/verify JWTs securing communication between our microservices. 

1. Generate a new key pair:

```
openssl ecparam -name secp384r1 -genkey -noout -out private.key
openssl ec -in private.key -pubout -outform PEM -out public.pem
```

2. Convert PEM format public key to JWKS:

```
cat public.pem | docker run -i danedmunds/pem-to-jwk:latest --jwks-out
```

That should output an output like this:

```
{"keys":[{"kty":"EC","kid":"Le1dRAA8XGFExzgeDVWWAZT91K74cwax5Fsroo0EKmc","crv":"P-384","x":"KJnJEOHR8dKeXOPwFB1br8OAPMmE2AVnvistrS-bbknODAi0UEifNbsks6BBAi-1","y":"bvkGrSQmmlcCepiPxdNAWGnGkyd7xBhe6Z10cXRauWoY8igwgP-t-6i20F_Tk7FI"}]}
```

3. Insert JWKS JSON generated in the step 2 above into the `keys` service helm chart:

Go to the `keys` chart's `values.yaml` file.
Find the `keysConfig` configmap section that looks like this:

```
configmaps:
  keysConfig:
    qlik.api.internal:
      edge-auth: |-
      ...
```

Replace the JWKS JSON snippet `for the service in question` with the snippet generated in step 2.

4. Replace private key and key ID in the service helm chart:

Set the indicated `Private Key Variable` to the contents of `private.key` file.
Set the indicated `Key ID Variable` to the `"kid"` value from the JWKS JSON obtained in step 2 (in this case `"Le1dRAA8XGFExzgeDVWWAZT91K74cwax5Fsroo0EKmc"`).

| Service                      | Private Key Variable                        | Key ID Variable                      |
| -----------------------------| --------------------------------------------| -------------------------------------|
| audit                        | config.tokenAuth.privateKey                 | config.tokenAuth.kid                 |
| chronos-worker               | jwt.privateKey                              | jwt.kid                              |
| collections                  | config.messaging.nats.tokenAuth.privateKey  | config.messaging.nats.tokenAuth.kid  |
| edge-auth                    | secrets.jwtPrivateKey                       | `[unset]`                            |
| engine                       | serviceJwt.jwtPrivateKey                    | serviceJwt.keyId                     |
| eventing                     | config.serviceJwt.privateKey                | config.serviceJwt.keyId              |
| groups                       | serviceJwt.jwtPrivateKey                    | serviceJwt.keyId                     |
| identity-providers           | serviceJwt.jwtPrivateKey                    | serviceJwt.keyId                     |
| insights                     | jwt.privateKey                              | jwt.kid                              |
| licenses                     | tokenAuth.privateKey                        | tokenAuth.kid                        |
| odag                         | auth.selfSigningKey                         | auth.kid                             |
| precedents                   | auth.selfSigningKey                         | auth.kid                             |
| qix-data-connection          | serviceJwt.jwtPrivateKey                    | serviceJwt.keyId                     |
| qix-datafiles                | tokenAuth.privateKey                        | tokenAuth.kid                        |
| qix-sessions                 | auth.serviceToken.privateKey                | auth.serviceToken.kid                |
| reporting                    | tokenAuth.privateKey                        | tokenAuth.kid                        |
| resource-library             | serviceJwt.jwtPrivateKey                    | serviceJwt.keyId                     |
| spaces                       | config.token.privateKey                     | config.token.kid                     |
| temporary-contents           | tokenAuth.privateKey                        | tokenAuth.kid                        |
| tenants                      | serviceJwt.jwtPrivateKey                    | serviceJwt.keyId                     |
| users                        | serviceJwt.jwtPrivateKey                    | serviceJwt.keyId                     |

5. `edge-auth` has sevaral other secrets that need periodic rotation. Namely:

- secrets.loginStateKey
- secrets.cookieKeys

To regenerate each of those, use:
```
openssl rand -base64 32
```
