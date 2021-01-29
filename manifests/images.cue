package manifests

import imgschema "github.com/dyncr/hydra/imgbuild:schema"

DyncrImage: imgschema.#GoBinImage & {
    binPath: "bin/dyncr"
    base: {
        ref: "docker://gcr.io/distroless/base"
        os: "linux"
        arch: "amd64"
    }
    ports: [8000]
    cmd: "/bin/dyncr"
    archive: "dyncr.image.tar"
}