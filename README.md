# NuoDB Control Plane

This repository is for releases and documentation for the NuoDB Control Plane, which enables automatic management of NuoDB databases in Kubernetes.

## Installation

To install the NuoDB Control Plane into your Kubernetes cluster, first add the Helm repository for the NuoDB Control Plane Helm charts.

```sh
helm repo add nuodb-cp https://nuodb.github.io/nuodb-cp-releases/charts
```

You can verify that the repo has been added by executing `helm search repo` to list the available Helm charts:

```console
$ helm repo add nuodb-cp https://nuodb.github.io/nuodb-cp-releases/charts
"nuodb-cp" has been added to your repositories

$ helm search repo nuodb-cp
NAME                      	CHART VERSION	APP VERSION	DESCRIPTION
nuodb-cp/nuodb-cp-3ds     	2.1.0        	2.1.0      	Cluster-scope resources and RBAC configuration ...
nuodb-cp/nuodb-cp-crd     	2.1.0        	2.1.0      	NuoDB Control Plane custom resource definitions...
nuodb-cp/nuodb-cp-doc     	2.1.0        	2.1.0      	Interactive documentation for the NuoDB Control...
nuodb-cp/nuodb-cp-operator	2.1.0        	2.1.0      	NuoDB Control Plane Operator
nuodb-cp/nuodb-cp-rest    	2.1.0        	2.1.0      	NuoDB Control Plane REST service
```

The NuoDB Control Plane can now be installed as follows:

```sh
helm install nuodb-cp-crd nuodb-cp/nuodb-cp-crd
helm install nuodb-cp-operator nuodb-cp/nuodb-cp-operator --set image.repository=ghcr.io/nuodb/nuodb-cp-images
helm install nuodb-cp-rest nuodb-cp/nuodb-cp-rest --set image.repository=ghcr.io/nuodb/nuodb-cp-images
```

## Helm charts

There are several Helm charts for installing the various components of the NuoDB Control Plane.

- `nuodb-cp-crd` contains [custom resource definitions](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/) used by the NuoDB Control Plane to manage NuoDB domains and databases.
This must always be installed.
- `nuodb-cp-operator` contains the [Kubernetes operator](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/) for managing NuoDB domains and databases.
This must always be installed.
- `nuodb-cp-rest` contains a REST service that exposes access to the NuoDB Control Plane in a Database as a Service (DBaaS) model.
This allows users without access to Kubernetes APIs to manage NuoDB domains and databases.
- `nuodb-cp-doc` exposes an endpoint for interactive documentation of the NuoDB Control Plane REST service.
See https://nuodb.github.io/nuodb-cp-releases/api-doc for non-interactive documentation of the REST service.
