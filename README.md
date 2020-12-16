# dyncr

Testbed for kubernetes development tooling. This shouldn't be used (yet).

- Provisioner for kind clusters that can be used for demoing an application (`make provision`) or setting up a test
environment (`make e2e`)
- Declarative cluster setup via `cuebectl`

The test application is a static site with ingress and oidc auth.

## Usage

- configure the environment variables for the oidc ingress (`manifests/flag.cue`)
- `make provision`
- hydra is deployed within the cluster but currently unused