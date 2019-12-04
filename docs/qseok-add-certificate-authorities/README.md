# qseok-add-certificate-authorities
How to add your own Certificate Authorities (CAs) to `qseok`

One of the ways to add a set of your own CAs to `qseok` is to append them to a list of public CAs and mount them into our service containers as a Kubernetes Volume. 
The relevant services will then use these "custom" CAs in conjunction with a set of standard CAs to make outbound TLS calls.

Our developers have built a helm chart that can automate the process of creating or populating a suitable Kubernetes PersistentVolume for you: cert-pvc-populator-master.zip.

NOTE: The instructions in the chart's Readme are tuned for the Qlik developer environments. You should run the `local` copy of the chart after unzipping it:

```
unzip cert-pvc-populator-master.zip
```

The chart operates on the base64 encoded CA certificate chain. If you have your CA chain in the file called `myCA.crt`, then do the following:

```
export MY_CA=$(cat myCA.crt | base64 | tr -d '\n')
```

Then you can use the exported variable with the unzipped chart as follows:

```
helm install --name cert-pvc-populator ./cert-pvc-populator-master --set pvc.create=true,job.customCA=$MY_CA
```

Or if you want to use an existing PVC, do the following:

```
helm install --name cert-pvc-populator ./cert-pvc-populator-master --set job.volumeClaimName="<your-pvc-name>",job.customCA=$MY_CA
```

NOTE: See the chart's Readme for additional configuration options, like StorageClass.

At this point you should have a Kubernetes Volume with your custom CAs appended to the bottom of the publicly available list provided with an Alpine distro.

Now you can use this volume when you install `qseok` as follows:

```
helm upgrade --install qsefe qlik/qsefe --set global.certs.enabled=true,global.certs.volume.existingVolumeClaim="certs-pvc"
```

Or if you used your own PVC:

```
helm upgrade --install qsefe qlik/qsefe --set global.certs.enabled=true,global.certs.volume.existingVolumeClaim="<your-pvc-name>"
```
