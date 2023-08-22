# GitOps with FluxCD

- [Presentation Slides](assets/GitOps-with-FluxCD.pdf)
- [K8SUG recording](https://youtu.be/Dg-v4hpNQlc)

## Requirements

This demo requires:

- a Kubernetes cluster named `cluster1`
- an optional Kubernetes cluster named `cluster2` will be used for the last step
- a domain managed by Cloudflare
- a fork of this repository

The Terraform steps require:

- export the environment variables: `CLOUDFLARE_EMAIL`, `CLOUDFLARE_API_KEY`, `GITHUB_OWNER`, `GITHUB_TOKEN` or update the terraform provider config
- the Kubeconfig `<HOME>/.kube/gitopsdemo-lab-cluster1-config.yaml` and `<HOME>/.kube/gitopsdemo-lab-cluster2-config.yaml`
- the variables `acme_email`, `domain`, `repository_name`

## Bootstrap Flux

```sh
flux bootstrap git \
  --url=ssh://git@github.com/celest-io/gitops-demo.git \
  --branch=main \
  --path=clusters/lab/cluster1
```

When requested by the bootstrap command add the SSH key to your repository.

## Step 01 - Deploy a Podinfo from a helm chart

Copy the content of (steps/01-deploy-podinfo)[steps/01-deploy-podinfo] to the root of the directory. Commit and push the changes.

Wait a few minutes or manually trigger the reconciliation process using the following command:

```sh
flux -n flux-system reconcile source git flux-system
```

Once everything has been reconciled, you can export the Podinfo service locally using the following command:

```sh
kubectl -n podinfo port-forward service/podinfo 9898:9898
```

Open a browser and access (http://localhost:9898)[http://localhost:9898]

## Step 02 - Update the deployed Podinfo pod to a newer version

In this step, we will update the version of Podinfo from `6.3.6` to `6.4.1`.
Copy the content of (steps/02-update-podinfo)[steps/02-update-podinfo] to the root of the directory. Commit and push the changes.

## Step 03 - Configure Podinfo service using post build variable substitution

We are going to change the background colour and text of Podinfo using variable substitution.
Copy the content of (steps/03-variables)[steps/03-variables] to the root of the directory. Commit and push the changes.

## Step 04 - Enable HelmChart drift detection

Edit the Podinfo deployment to manually change the colour or message.

```sh
kubcetl -n podinfo edit deployments.apps podinfo
```

The changes are not going to be reverted by FluxCD until we change a value in the associated HelmRelease. By default Flux doesn't detect drifts and revert changes in helm release. It provides an option to enable the feature.
Copy the content of (steps/04-drift-detection)[steps/04-drift-detection] to the root of the directory. Commit and push the changes.

## Step 05 - Variables from secrets and Dependencies between

In this step, we are going to deploy Cert-Manager and create a DNS01 issuer for Letsencrypt using Cloudflare.
We will introduce the notion of dependencies between Flux resources. The dependencies will be as follow:

- Create shared helm repositories
- Create the Cert-Manager CRDs
- Deploy Cert-Manager
- Configure a ClusterIssuer

In the `terraform/cluster1` directory, apply the terraform configuration. The script will create a Cloudlfare token for the domain and will create a secret in the `flux-system` namespace containing this token and other variables.

Copy the content of (steps/05-cert-manager)[steps/05-cert-manager] to the root of the directory. Commit and push the changes.

## Step 06 - Expose the Podinfo service via a Traefik ingress

In this step, we are going to:

- deploy a Traefik ingress controller
- deploy the External DNS controller
- expose the Podinfo service on an https ingress (Cert-Manager will issue a certificate)

Copy the content of (steps/06-traefik-ingress)[steps/06-traefik-ingress] to the root of the directory. Commit and push the changes.

The service will be accessible via `https://podinfo.cluster1.lab.<domain>/`

## Step 07 - Configure a new Cluster

In this step, we will bootstrap a new cluster using the FluxCD terraform provider and configure it to expose Podinfo via a Traefik. By using naming conventions and using variable injections, we can easily manage multiple clusters from the same manifests without the need to patch things.

In the `terraform/cluster2` directory, apply the terraform configuration. The script will:

- create a new ssh-key
- add the ssh-key to the repository
- bootstrap FluxCD in your `gitops-demo` repository
- create a Cloudlfare token for the domain
- create a secret in the `flux-system` namespace containing this token and other variables.

Copy the content of (steps/07-new-cluster)[steps/07-new-cluster] to the root of the directory. Commit and push the changes.

The service will be accessible via `https://podinfo.cluster2.lab.<domain>/`
