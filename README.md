# dyncr

Testbed for kubernetes development tooling. This shouldn't be used (yet).

- Provisioner for kind clusters that can be used for demoing an application (`make provision`) or setting up a test
environment (`make e2e`)
- Declarative cluster setup via `cuebectl`

The test application is a static site with ingress and oidc auth.

## Usage

- add `127.0.0.1 dyncr.localhost` to `/etc/hosts`
    - hydra requires non-https urls to end in `.localhost`
- `make provision`
    - have to configure coredns for redirects - can't use hostalias for nginx ingress
- visit `dyncr.localhost`