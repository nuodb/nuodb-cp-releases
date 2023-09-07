# DBaaS Quick Start Guide

NuoDB Control Plane works with [Kubernetes][1] locally or in the cloud.
This document describes how to provision NuoDB databases in multi-tenancy model by using NuoDB Control Plane.

## Prerequisites

- A running [Kubernetes cluster][2]
- [kubectl][3] installed and able to access the cluster.
- [Helm 3.x][4] installed.

## Installing NuoDB Control Plane

The NuoDB Control Plane consists of [Custom Resource Definitions][5] and the following workloads:

- *NuoDB CP Operator*, which enforces the desired state of the NuoDB [custom resources][6].
- *NuoDB CP REST service*, that exposes a REST API allowing users to manipulate and inspect DBaaS entities.

### Configure Kubernetes

Create a namespace for all NuoDB resources.

```sh
kubectl create namespace nuodb-cp-system
kubectl config set-context --current --namespace=nuodb-cp-system
```

### Configure Helm repositories

Add the official Helm repositories.

```sh
helm repo add jetstack https://charts.jetstack.io
helm repo add nuodb-cp https://nuodb.github.io/nuodb-cp-releases/charts
helm repo update
```

### Install Cert Manager

To enable [admission webhooks][7] that perform synchronous validation of NuoDB custom resource definitions, [cert-manager](https://github.com/cert-manager/cert-manager) should be installed to automatically generate certificates for the webhook server.

```sh
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace
```

Wait for Cert Manager to become available.

```sh
kubectl -n cert-manager wait pod --all --for=condition=Ready
```

### Install NuoDB CP using Helm charts

```sh
helm upgrade --install nuodb-cp-crd nuodb-cp/nuodb-cp-crd \
    --namespace nuodb-cp-system

helm upgrade --install nuodb-cp-operator nuodb-cp/nuodb-cp-operator \
    --namespace nuodb-cp-system \
    --set cpOperator.webhooks.enabled=true \
    --set 'cpOperator.extraArgs[0]=--ingress-https-port=48006' # Enables connecting to databases with port-forwarding

helm upgrade --install nuodb-cp-rest nuodb-cp/nuodb-cp-rest \
    --namespace nuodb-cp-system \
    --set cpRest.authentication.enabled=true \
    --set cpRest.authentication.admin.create=true \
    --set cpRest.baseDomainName=dbaas.localtest.me # Enables connecting to databases with port-forwarding
```

Wait for NuoDB Control Plane to become available.

```sh
kubectl -n nuodb-cp-system -l app=nuodb-cp-operator wait pod --all --for=condition=Ready
kubectl -n nuodb-cp-system -l app=nuodb-cp-rest wait pod --all --for=condition=Ready
```

## Creating NuoDB Database

Once the Control Plane is deployed, projects and databases can now be created.

### Access and Authentication

This guide will use port forwarding and `cURL` to demonstrate how to create projects and databases through the REST service.

```sh
kubectl port-forward svc/nuodb-cp-rest 8080 2>&1 >/dev/null &
```

To successfully authenticate with the REST API endpoints, get the *system/admin* user's password from the cluster:

```sh
PASS=$(kubectl get secret dbaas-user-system-admin -o jsonpath='{.data.password}' | base64 -d)
BASE_URL="http://api.dbaas.localtest.me:8080"
```

### Create Project

Create a new project *messaging* in organization *acme*:

```sh
curl -u "system/admin:$PASS" -X PUT -H 'Content-Type: application/json' \
    $BASE_URL/projects/acme/messaging \
    -d '{"sla": "dev", "tier": "n0.small"}'
```

Wait for the project to become available.

```sh
while [ "$(curl -s -u "system/admin:$PASS" $BASE_URL/projects/acme/messaging | jq '.status.ready')" = "false" ]; do echo "Waiting ..."; sleep 5; done; echo "Domain is available"
```

### Create database

Create a new database *demo* in project *messaging*:

```sh
curl -u "system/admin:$PASS" -X PUT -H 'Content-Type: application/json' \
    $BASE_URL/databases/acme/messaging/demo \
    -d '{"dbaPassword": "secret"}'
```

Wait for the database to become available.

```sh
while [ "$(curl -s -u "system/admin:$PASS" $BASE_URL/databases/acme/messaging/demo | jq '.status.ready')" = "false" ]; do echo "Waiting ..."; sleep 5; done; echo "Database is available"
```

### Connect to Database

This guide will use port forwarding to connect to the NuoDB database.

```sh
ADMIN_SVC=$(kubectl get svc -l 'cp.nuodb.com/organization=acme,cp.nuodb.com/project=messaging,!cp.nuodb.com/database' -oname | grep "clusterip")
DB_SVC=$(kubectl get svc -l "cp.nuodb.com/organization=acme,cp.nuodb.com/project=messaging,cp.nuodb.com/database" -oname)
kubectl port-forward $ADMIN_SVC 48004 2>&1 >/dev/null &
kubectl port-forward $DB_SVC 48006 2>&1 >/dev/null &
```

Connect to the NuoDB database via `nuosql` (requires [nuodb-client][8] package v20230228 or later).

```sh
CA_CERT="$(curl -s -u "system/admin:$PASS" $BASE_URL/databases/acme/messaging/demo | jq -r '.status.caPem')"
DB_URL="$(curl -s -u "system/admin:$PASS" $BASE_URL/databases/acme/messaging/demo | jq -r '.status.sqlEndpoint')"
nuosql "demo@${DB_URL}" --user dba --password secret --connection-property trustedCertificates="$CA_CERT"
```

### Cleanup

- Delete all custom resources that have been created in `nuodb-cp-system` namespace.

```sh
kubectl config set-context --current --namespace=nuodb-cp-system
kubectl get databases.cp.nuodb.com -o name | xargs kubectl delete
kubectl get domains.cp.nuodb.com -o name | xargs kubectl delete
kubectl get servicetiers.cp.nuodb.com -o name | xargs kubectl delete
kubectl get helmfeatures.cp.nuodb.com -o name | xargs kubectl delete
kubectl get databasequotas.cp.nuodb.com -o name | xargs -r kubectl delete
kubectl get secrets -o name --selector=cp.nuodb.com/organization | xargs -r kubectl delete
kubectl get pvc -o name --selector=group=nuodb | xargs -r kubectl delete
```

- Cleanup the NuoDB CP Helm charts in the following order:

```sh
helm uninstall nuodb-cp-rest
helm uninstall nuodb-cp-operator
helm uninstall nuodb-cp-crd
```

- Delete the NuoDB CP namespace:

```sh
kubectl delete namespace nuodb-cp-system
```

- Cleanup Cert Manager Helm chart:

```sh
helm uninstall cert-manager --namespace cert-manager
```

[1]: https://kubernetes.io/docs/home/
[2]: https://kubernetes.io/docs/concepts/overview/components/
[3]: https://kubernetes.io/docs/tasks/tools/
[4]: https://helm.sh/
[5]: https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#customresourcedefinitions
[6]: https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#custom-resources
[7]: https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/
[8]: https://github.com/nuodb/nuodb-client/releases