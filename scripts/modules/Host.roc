import CpuArchOS

Host := {}.{
    Optimize : [Debug, ReleaseFast, ReleaseSafe, ReleaseSmall]

    optimize_str : Optimize -> Str
    optimize_str = |o| {
        match o {
            Debug => "Debug"
            ReleaseFast => "ReleaseFast"
            ReleaseSafe => "ReleaseSafe"
            ReleaseSmall => "ReleaseSmall"
        }
    }

    LibKind : [StaticLib, WasmObj]

    HostTarget : {
        name : CpuArchOS,
        name_str : Str,
        zig_triple : Str,
        kind : LibKind,
        lib_file : Str,
        mcpu : [NoCpu, Cpu(Str)],
    }

    to_target : CpuArchOS -> HostTarget
    to_target = |cpu_arch_os| {
        match cpu_arch_os {
            Wasm32 => {
                name: Wasm32,
                name_str: "wasm32",
                zig_triple: "wasm32-freestanding",
                kind: WasmObj,
                lib_file: "libhost.o.wasm",
                mcpu: NoCpu,
            }
            _ => crash "hfjaslhfkafaflhksdjaflhsdkjhafsdkj"
        }
    }

    all_targets : List(HostTarget)
    all_targets = [
        {
            name: Wasm32,
            name_str: "wasm32",
            zig_triple: "wasm32-freestanding",
            kind: WasmObj,
            lib_file: "libhost.o.wasm",
            mcpu: NoCpu,
        },
        {
            name: X64musl,
            name_str: "x64musl",
            zig_triple: "x86_64-linux-musl",
            kind: StaticLib,
            lib_file: "libhost.a",
            mcpu: NoCpu,
        },
        {
            name: X64v1musl,
            name_str: "x64v1musl",
            zig_triple: "x86_64-linux-musl",
            kind: StaticLib,
            lib_file: "libhost.a",
            mcpu: Cpu("x86_64"),
        },
        {
            name: Arm64musl,
            name_str: "arm64musl",
            zig_triple: "aarch64-linux-musl",
            kind: StaticLib,
            lib_file: "libhost.a",
            mcpu: NoCpu,
        },
        {
            name: Arm64v1musl,
            name_str: "arm64v1musl",
            zig_triple: "aarch64-linux-musl",
            kind: StaticLib,
            lib_file: "libhost.a",
            mcpu: Cpu("baseline"),
        },
        {
            name: X64mac,
            name_str: "x64mac",
            zig_triple: "x86_64-macos",
            kind: StaticLib,
            lib_file: "libhost.a",
            mcpu: NoCpu,
        },
        {
            name: Arm64mac,
            name_str: "arm64mac",
            zig_triple: "aarch64-macos",
            kind: StaticLib,
            lib_file: "libhost.a",
            mcpu: NoCpu,
        },
        {
            name: X64win,
            name_str: "x64win",
            zig_triple: "x86_64-windows",
            kind: StaticLib,
            lib_file: "host.lib",
            mcpu: NoCpu,
        },
        {
            name: X64mingw,
            name_str: "x64mingw",
            zig_triple: "x86_64-windows-gnu",
            kind: StaticLib,
            lib_file: "host.lib",
            mcpu: NoCpu,
        },
        {
            name: Arm64win,
            name_str: "arm64win",
            zig_triple: "aarch64-windows",
            kind: StaticLib,
            lib_file: "host.lib",
            mcpu: NoCpu,
        },
        {
            name: Arm64mingw,
            name_str: "arm64mingw",
            zig_triple: "aarch64-windows-gnu",
            kind: StaticLib,
            lib_file: "host.lib",
            mcpu: NoCpu,
        },
    ]
}
