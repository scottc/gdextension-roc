## Host rows we know how to emit in platform main.roc targets:

CpuArchOS := [
    Wasm32,
    X64musl,
    X64v1musl,
    Arm64musl,
    Arm64v1musl,
    X64mac,
    Arm64mac,
    X64win,
    X64mingw,
    Arm64win,
    Arm64mingw,
].{
    all : List(CpuArchOS)
    all = [
        Wasm32,
        X64musl,
        X64v1musl,
        Arm64musl,
        Arm64v1musl,
        X64mac,
        Arm64mac,
        X64win,
        X64mingw,
        Arm64win,
        Arm64mingw,
    ]

    auto : List(CpuArchOS)
    auto = [CpuArchOS.Wasm32, CpuArchOS.X64musl]



    to_name : CpuArchOS -> Str
    to_name = |cpu_arch_os| {
        match cpu_arch_os {
            Wasm32 => "wasm32"
            X64musl => "x64musl"
            X64v1musl => "x64v1musl"
            Arm64musl => "arm64musl"
            Arm64v1musl => "arm64v1musl"
            X64mac => "x64mac"
            Arm64mac => "arm64mac"
            X64win => "x64win"
            X64mingw => "x64mingw"
            Arm64win => "arm64win"
            Arm64mingw => "arm64mingw"
        }
    }
}
