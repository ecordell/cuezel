package schema

#GoBinImage: {
    binPath: string
    base: {
        ref: string
        arch: string
        os: string
    }
    ports?: [...uint]
    name?: string
    archive?: string
    cmd: string
}