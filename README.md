# Branching and tagging conventions for releases

The `latest` branch and branches of the form `v<major>.<minor>-dev` are used to track changes to the NuoDB Control Plane REST API captured in the [OpenAPI spec](/openapi.yaml).
All tags for NuoDB Control Plane releases should be applied to commits on one of these branches.

Releases with patch version `0` will appear in the commit history of `latest`, while releases with non-`0` patch versions will appear in the commit history of the corresponding `v<major>.<minor>-dev` branch for the major and minor version.
For example, release tag `v2.1.0` should appear on `latest`, while release tag `v2.1.1` should appear on `v2.1-dev`.

These conventions are enforced by a GitHub Actions workflow defined in the `main` branch that adjusts release tags for releases created externally.

The reason why major and minor releases are on a branch named `latest` is because `main` is already used for documentation and for CI scripting, and because it is convenient to access the latest version of the REST API by using the [`latest`](https://raw.githubusercontent.com/nuodb/nuodb-cp-releases/latest/openapi.yaml) reference.

> *NOTE*: It is possible for a patch release to exist that is later than the head commit on `latest`, but patch releases cannot introduce changes to the REST API, therefore the head commit on `latest` will always be the most recent version of the REST API.
