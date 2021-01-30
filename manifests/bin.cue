package manifests

import (
  binschema "github.com/dyncr/hydra/runbin:schema"
)

DyncrBin: binschema.#RunBin & {
    cmd: "go"
    args: ["build", "-o", outfile, "./cmd/dyncr"]
    outfile: "./bin/dyncr"
}