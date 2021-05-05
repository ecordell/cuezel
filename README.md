# Cuezel

Cuezel is a [CUE](https://cuelang.org/)-based build system, a la `make` or `bazel`.

 - Build steps are cuelang definitions
 - Cuezel plugins handle a particular type of step
 - Build steps depend on other steps by referencing their output directly

# Status: Prototype

You can play with it, but some critical features are missing. 

In the current state it is largely only useful for standing up local development of kubernetes controllers, due to a lack of plugins (plugins are all in-tree at the moment vs. actually plugable):

Current available plugins:

- `runbin`: run a binary
- `imgbuild`: build a docker image (no container runtime required)
- `provision`: start a kind cluster
- `cuebectl`: any objects identified as kube manifests are reconciled with [cuebectl](https://github.com/cuebernetes/cuebectl)

# Example

The example in this repo:

 - builds an oidc proxy binary that does dynamic client registration (`dyncr`) ([manifest](manifests/bin.cue))
 - builds an image with that binary in it ([manifest](manifests/images.cue))
 - stands up a kind cluster ([manifest](manifests/cluster.cue))
 - installs ory hydra as an oidc provider ([manifest](manifests/hydra.cue))
 - installs `dyncr` and a `flag` to protect with the proxy ([manifest](manfiests/images.cue))

## Quickstart Example

- add `127.0.0.1 dyncr.localhost` to `/etc/hosts`
    - hydra requires non-https urls to end in `.localhost`
- `make provision`
    - have to configure coredns for redirects - can't use hostalias for nginx ingress
- visit `dyncr.localhost`