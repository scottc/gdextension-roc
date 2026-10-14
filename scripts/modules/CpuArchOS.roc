## Host rows we know how to emit in platform main.roc targets:
import StringHelper

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
    auto = [CpuArchOS.Wasm32, CpuArchOS.X64musl] # TODO: detect local native arch that this was compiled against @ comptime.

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

    from_name : Str -> CpuArchOS
    from_name = |str| {
        match str {
            "wasm32" => Wasm32
            "x64musl" => X64musl
            "x64v1musl" => X64v1musl
            "arm64musl" => Arm64musl
            "arm64v1musl" => Arm64v1musl
            "x64mac" => X64mac
            "arm64mac" => Arm64mac
            "x64win" => X64win
            "x64mingw" => X64mingw
            "arm64win" => Arm64win
            "arm64mingw" => Arm64mingw
            _ => crash "Got unexpected string value, was expecting a valid CpuArchOS value."
        }
    }

    ## Takes raw string args, parses flag: --targets=wasm32,x64musl
    parse_targets_flag : List(Str) -> List(CpuArchOS)
    parse_targets_flag = |args| {
        targets_key = "--targets="
        for str in args {
            if str.starts_with(targets_key) {
                id = str.replace_first(targets_key, "")
                match id {
                    "all" => return all
                    "auto" => return auto
                    raw => {
                        parts = StringHelper.split_comma(raw)
                        if parts.is_empty() {
                            return auto # default
                        } else {
                            return parts.map(from_name)
                        }
                    }
                }
            }
        }
        CpuArchOS.auto
    }
}
