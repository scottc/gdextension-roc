#!/usr/bin/env roc

#
# Usage:
#   roc run scripts/ci.roc
#   roc run scripts/ci.roc -- quick
#   roc run scripts/ci.roc -- full
#   roc run scripts/ci.roc -- full deep-wasm -Doptimize=Debug
#   roc run scripts/ci.roc -- full --publish
#   GITHUB_TOKEN=ghp_... roc run scripts/ci.roc -- full --publish --tag=v0.1.0
#
# Web export runs only for the primary engine (godot / 4.7.2 templates).
# Other engines still build .so + wasm; they skip headless Web export unless
# matching export templates are installed.
#

## Continuous Integration — engine × host matrix (roc-build)
app [main!] {
    pf: platform "https://github.com/scottc/roc-build/releases/download/0.0.1-pre-alpha-test1/8jZuyEFpCc7ep6yu2iXBT4cAYoxZdjTk5kxShUCMXqgx.tar.zst",
}

import pf.Build
import pf.Log

# =============================================================================
# Domain types
# =============================================================================

Optimize : [Debug, ReleaseFast, ReleaseSafe, ReleaseSmall]

CiMode : [Quick, Full]

LibKind : [StaticLib, WasmObj]

HostTier : [Primary, Secondary, Experimental]

EnginePipeline : [FullBuild, DumpOnly]

HostName : [
    Wasm32,
    X64Musl,
    X64V1Musl,
    Arm64Musl,
    Arm64V1Musl,
    X64Mac,
    Arm64Mac,
    X64Win,
    X64Mingw,
    Arm64Win,
    Arm64Mingw,
]

HostTarget : {
    name : HostName,
    name_str : Str,
    zig_triple : Str,
    kind : LibKind,
    lib_file : Str,
    mcpu : [NoCpu, Cpu(Str)],
    baseline : [NoBaseline, Baseline(HostName)],
    tier : HostTier,
}

EngineName : [Godot, Godot451, Redot, Rex]

DumpKind : [GdextensionInterface, GdextensionInterfaceJson, ExtensionApi]

EngineDump : {
    kind : DumpKind,
    program : Str,
    args : List(Str),
    description : Str,
}

EngineSpec : {
    name : EngineName,
    slug : Str,
    program : Str,
    required_in_full : Bool,
    is_primary : Bool,
    ## Headless Web export needs matching export templates (only primary has them in nix).
    export_web : Bool,
    pipeline : EnginePipeline,
    dumps : List(EngineDump),
}

NodeId : U64

CiRoots : {
    smoke_out_root : Str,
    bundle_out_root : Str,
    platform_out_root : Str,
    glue_out_root : Str,
    vendor_out_root : Str,
    project_template : Str,
    project_name : Str,
    host_entry : Str,
    zig_glue_roc : Str,
}

ReplacePair : {
    find : Str,
    replace : Str,
}

PublishOpts : {
    enabled : Bool,
    tag : Str,
    token : Str,
}

# =============================================================================
# Id allocator
# =============================================================================

take_id : NodeId -> (NodeId, NodeId)
take_id = |next| (next, next + 1)

# =============================================================================
# Paths
# =============================================================================

engine_vendor_dir : EngineSpec -> Str
engine_vendor_dir = |e| "dump-out/${e.slug}"

engine_platform_dir : EngineSpec -> Str
engine_platform_dir = |e| "platform-out/${e.slug}"

engine_glue_dir : EngineSpec -> Str
engine_glue_dir = |e| "host/glue-out/${e.slug}"

engine_platform_main : EngineSpec -> Str
engine_platform_main = |e| "${engine_platform_dir(e)}/main.roc"

engine_host_out_path : EngineSpec, HostTarget -> Str
engine_host_out_path = |e, t|
    "${engine_platform_dir(e)}/targets/${t.name_str}/${t.lib_file}"

engine_host_out_dir : EngineSpec, HostTarget -> Str
engine_host_out_dir = |e, t|
    "${engine_platform_dir(e)}/targets/${t.name_str}"

engine_abi_file : EngineSpec -> Str
engine_abi_file = |e| "${engine_glue_dir(e)}/roc_platform_abi.zig"

engine_gdext_file : EngineSpec -> Str
engine_gdext_file = |e| "${engine_glue_dir(e)}/gdextension_interface.zig"

engine_gde_call_file : EngineSpec -> Str
engine_gde_call_file = |e| "${engine_glue_dir(e)}/gde_call.zig"

engine_abi_impl_file : EngineSpec -> Str
engine_abi_impl_file = |e| "${engine_glue_dir(e)}/zig_platform_abi_impl.zig"

engine_smoke_out : EngineSpec -> Str
engine_smoke_out = |e| "smoke-out/${e.slug}"

engine_smoke_workspace : EngineSpec -> Str
engine_smoke_workspace = |e| "smoke-out/${e.slug}/workspace"

engine_project_dir : EngineSpec -> Str
engine_project_dir = |e| "smoke-out/${e.slug}/workspace/my_game"

engine_project_main : EngineSpec -> Str
engine_project_main = |e| "${engine_project_dir(e)}/main.roc"

engine_project_platform_dir : EngineSpec -> Str
engine_project_platform_dir = |e| "${engine_project_dir(e)}/platform"

engine_project_platform_main : EngineSpec -> Str
engine_project_platform_main = |e| "${engine_project_platform_dir(e)}/main.roc"

engine_project_linux_out : EngineSpec -> Str
engine_project_linux_out = |e| "${engine_project_dir(e)}/my_game.so"

engine_project_temp_a : EngineSpec -> Str
engine_project_temp_a = |e| "${engine_project_dir(e)}/temp.a"

engine_project_wasm : EngineSpec -> Str
engine_project_wasm = |e| "${engine_project_dir(e)}/my_game.wasm"

engine_project_godot : EngineSpec -> Str
engine_project_godot = |e| "${engine_project_dir(e)}/project.godot"

engine_export_index : EngineSpec -> Str
engine_export_index = |e| "${engine_project_dir(e)}/export/index.html"

engine_bundle_out : EngineSpec -> Str
engine_bundle_out = |e| "bundle-out/${e.slug}"

engine_bundle_workspace : EngineSpec -> Str
engine_bundle_workspace = |e| "bundle-out/${e.slug}/workspace"

engine_bundle_platform_name : EngineSpec -> Str
engine_bundle_platform_name = |e| "platform-${e.slug}"

engine_bundle_platform_dest : EngineSpec -> Str
engine_bundle_platform_dest = |e|
    "${engine_bundle_workspace(e)}/${engine_bundle_platform_name(e)}"

engine_local_platform_pkg : Str
engine_local_platform_pkg = "./platform/main.roc"

# =============================================================================
# Matrices
# =============================================================================

host_targets : List(HostTarget)
host_targets = [
    {
        name: Wasm32,
        name_str: "wasm32",
        zig_triple: "wasm32-freestanding",
        kind: WasmObj,
        lib_file: "libhost.o.wasm",
        mcpu: NoCpu,
        baseline: NoBaseline,
        tier: Primary,
    },
    {
        name: X64Musl,
        name_str: "x64musl",
        zig_triple: "x86_64-linux-musl",
        kind: StaticLib,
        lib_file: "libhost.a",
        mcpu: NoCpu,
        baseline: Baseline(X64V1Musl),
        tier: Primary,
    },
    {
        name: X64V1Musl,
        name_str: "x64v1musl",
        zig_triple: "x86_64-linux-musl",
        kind: StaticLib,
        lib_file: "libhost.a",
        mcpu: Cpu("x86_64"),
        baseline: NoBaseline,
        tier: Primary,
    },
    {
        name: Arm64Musl,
        name_str: "arm64musl",
        zig_triple: "aarch64-linux-musl",
        kind: StaticLib,
        lib_file: "libhost.a",
        mcpu: NoCpu,
        baseline: Baseline(Arm64V1Musl),
        tier: Secondary,
    },
    {
        name: Arm64V1Musl,
        name_str: "arm64v1musl",
        zig_triple: "aarch64-linux-musl",
        kind: StaticLib,
        lib_file: "libhost.a",
        mcpu: Cpu("generic"),
        baseline: NoBaseline,
        tier: Secondary,
    },
    {
        name: X64Mac,
        name_str: "x64mac",
        zig_triple: "x86_64-macos",
        kind: StaticLib,
        lib_file: "libhost.a",
        mcpu: NoCpu,
        baseline: NoBaseline,
        tier: Secondary,
    },
    {
        name: Arm64Mac,
        name_str: "arm64mac",
        zig_triple: "aarch64-macos",
        kind: StaticLib,
        lib_file: "libhost.a",
        mcpu: NoCpu,
        baseline: NoBaseline,
        tier: Secondary,
    },
    {
        name: X64Win,
        name_str: "x64win",
        zig_triple: "x86_64-windows-msvc",
        kind: StaticLib,
        lib_file: "host.lib",
        mcpu: NoCpu,
        baseline: NoBaseline,
        tier: Secondary,
    },
    {
        name: X64Mingw,
        name_str: "x64mingw",
        zig_triple: "x86_64-windows-gnu",
        kind: StaticLib,
        lib_file: "host.lib",
        mcpu: NoCpu,
        baseline: NoBaseline,
        tier: Secondary,
    },
    {
        name: Arm64Win,
        name_str: "arm64win",
        zig_triple: "aarch64-windows-msvc",
        kind: StaticLib,
        lib_file: "host.lib",
        mcpu: NoCpu,
        baseline: NoBaseline,
        tier: Experimental,
    },
    {
        name: Arm64Mingw,
        name_str: "arm64mingw",
        zig_triple: "aarch64-windows-gnu",
        kind: StaticLib,
        lib_file: "host.lib",
        mcpu: NoCpu,
        baseline: NoBaseline,
        tier: Experimental,
    },
]

engine_specs : List(EngineSpec)
engine_specs = [
    {
        name: Godot,
        slug: "godot",
        program: "godot",
        required_in_full: Bool.True,
        is_primary: Bool.True,
        export_web: Bool.True,
        pipeline: FullBuild,
        dumps: [
            {
                kind: GdextensionInterface,
                program: "godot",
                args: ["--headless", "--dump-gdextension-interface"],
                description: "Godot: dump-gdextension-interface",
            },
            {
                kind: GdextensionInterfaceJson,
                program: "godot",
                args: ["--headless", "--dump-gdextension-interface-json"],
                description: "Godot: dump-gdextension-interface-json",
            },
            {
                kind: ExtensionApi,
                program: "godot",
                args: ["--headless", "--dump-extension-api"],
                description: "Godot: dump-extension-api",
            },
        ],
    },
    {
        name: Godot451,
        slug: "godot_4_5_1",
        program: "godot4.5",
        required_in_full: Bool.True,
        is_primary: Bool.False,
        # Needs 4.5.1 export templates; nix env only ships 4.7.2 templates.
        export_web: Bool.False,
        pipeline: FullBuild,
        dumps: [
            {
                kind: GdextensionInterface,
                program: "godot4.5",
                args: ["--headless", "--dump-gdextension-interface"],
                description: "Godot 4.5.1: dump-gdextension-interface",
            },
            {
                kind: ExtensionApi,
                program: "godot4.5",
                args: ["--headless", "--dump-extension-api"],
                description: "Godot 4.5.1: dump-extension-api",
            },
        ],
    },
    {
        name: Redot,
        slug: "redot",
        program: "redot",
        required_in_full: Bool.True,
        is_primary: Bool.False,
        export_web: Bool.False,
        pipeline: FullBuild,
        dumps: [
            {
                kind: GdextensionInterface,
                program: "redot",
                args: ["--headless", "--dump-gdextension-interface"],
                description: "Redot: dump-gdextension-interface",
            },
            {
                kind: ExtensionApi,
                program: "redot",
                args: ["--headless", "--dump-extension-api"],
                description: "Redot: dump-extension-api",
            },
        ],
    },
    {
        name: Rex,
        slug: "rex",
        program: "rex",
        required_in_full: Bool.False,
        is_primary: Bool.False,
        export_web: Bool.False,
        pipeline: DumpOnly,
        dumps: [
            {
                kind: GdextensionInterface,
                program: "rex",
                args: ["--headless", "--dump-gdextension-interface"],
                description: "Rex: dump-gdextension-interface",
            },
            {
                kind: ExtensionApi,
                program: "rex",
                args: ["--headless", "--dump-extension-api"],
                description: "Rex: dump-extension-api",
            },
        ],
    },
]

glue_replace_pairs : List(ReplacePair)
glue_replace_pairs = [
    {
        find:
            \\    fn nativeWriteStderr(_: ?*anyopaque, data: []const u8) void {
            \\        std.Io.File.stderr().writeStreamingAll(std.Io.Threaded.global_single_threaded.io(), data) catch {};
            \\    }
        ,
        replace:
            \\// PATCHED BY scripts/ci.roc (glue)
            \\fn nativeWriteStderr(_: ?*anyopaque, data: []const u8) void {
            \\    _ = data;
            \\}
        ,
    },
    {
        find:
            \\    fn nativeOnFatal(_: ?*anyopaque) noreturn {
            \\        std.process.exit(1);
            \\    }
        ,
        replace:
            \\// PATCHED BY scripts/ci.roc (glue)
            \\fn nativeOnFatal(_: ?*anyopaque) noreturn {
            \\    if (comptime @import("builtin").cpu.arch != .wasm32) {
            \\        std.debug.print("[roc] onFatal / crash path", .{});
            \\        std.process.exit(1);
            \\    } else {
            \\        @trap();
            \\    }
            \\}
        ,
    },
]

# =============================================================================
# Helpers
# =============================================================================

parse_optimize : List(Str) -> Optimize
parse_optimize = |args| {
    var $mode = Debug
    for a in args {
        match a {
            "-Doptimize=Debug" => {
                $mode = Debug
            }
            "-Doptimize=ReleaseFast" => {
                $mode = ReleaseFast
            }
            "-Doptimize=ReleaseSafe" => {
                $mode = ReleaseSafe
            }
            "-Doptimize=ReleaseSmall" => {
                $mode = ReleaseSmall
            }
            _ => {}
        }
    }
    $mode
}

parse_mode : List(Str) -> CiMode
parse_mode = |args| {
    if List.contains(args, "quick") {
        Quick
    } else if List.contains(args, "full") {
        Full
    } else {
        Full
    }
}

parse_publish : List(Str) -> PublishOpts
parse_publish = |args| {
    var $enabled = Bool.False
    var $tag = ""
    var $token = ""

    for a in args {
        if a == "--publish" or a == "publish" {
            $enabled = Bool.True
        } else if a.starts_with("--tag=") {
            $tag = a.drop_prefix("--tag=")
        } else if a.starts_with("--github-token=") {
            $token = a.drop_prefix("--github-token=")
        } else {
            {}
        }
    }

    {
        enabled: $enabled,
        tag: $tag,
        token: $token,
    }
}

mode_label : CiMode -> Str
mode_label = |m| {
    match m {
        Quick => "quick"
        Full => "full"
    }
}

optimize_label : Optimize -> Str
optimize_label = |o| {
    match o {
        Debug => "Debug"
        ReleaseFast => "ReleaseFast"
        ReleaseSafe => "ReleaseSafe"
        ReleaseSmall => "ReleaseSmall"
    }
}

pipeline_label : EnginePipeline -> Str
pipeline_label = |p| {
    match p {
        FullBuild => "full-build"
        DumpOnly => "dump-only"
    }
}

default_roots : CiRoots
default_roots = {
    smoke_out_root: "smoke-out",
    bundle_out_root: "bundle-out",
    platform_out_root: "platform-out",
    glue_out_root: "host/glue-out",
    vendor_out_root: "dump-out",
    project_template: "ci",
    project_name: "My Game",
    host_entry: "host/host.zig",
    zig_glue_roc: "vendor/roc/nightly-2026-10-09-258ab27/ZigGlue.roc",
}

optimize_flag : Optimize -> Str
optimize_flag = |o| {
    match o {
        Debug => "-ODebug"
        ReleaseFast => "-OReleaseFast"
        ReleaseSafe => "-OReleaseSafe"
        ReleaseSmall => "-OReleaseSmall"
    }
}

effective_optimize : HostTarget, Optimize -> Optimize
effective_optimize = |t, o| {
    match t.kind {
        WasmObj => ReleaseFast
        StaticLib => o
    }
}

select_hosts : CiMode -> List(HostTarget)
select_hosts = |mode| {
    match mode {
        Quick =>
            host_targets.fold([], |acc, t| {
                match t.tier {
                    Primary => List.append(acc, t)
                    _ => acc
                }
            })
        Full => host_targets
    }
}

list_has_host_name : List(HostTarget), HostName -> Bool
list_has_host_name = |hosts, name| {
    hosts.fold(Bool.False, |acc, h| acc or h.name == name)
}

find_host : HostName -> Try(HostTarget, [UnknownHost(HostName)])
find_host = |name| {
    for t in host_targets {
        if t.name == name {
            return Ok(t)
        }
    }
    Err(UnknownHost(name))
}

with_baselines : List(HostTarget) -> List(HostTarget)
with_baselines = |selected| {
    var $out = selected
    for t in selected {
        match t.baseline {
            NoBaseline => {}
            Baseline(base_name) => {
                if list_has_host_name($out, base_name) {
                    {}
                } else {
                    match find_host(base_name) {
                        Ok(base) => {
                            $out = List.append($out, base)
                        }
                        Err(_) => {}
                    }
                }
            }
        }
    }
    $out
}

select_engines : CiMode -> List(EngineSpec)
select_engines = |mode| {
    match mode {
        Full => engine_specs
        Quick =>
            engine_specs.fold([], |acc, e| {
                match e.name {
                    Rex => acc
                    _ => List.append(acc, e)
                }
            })
    }
}

engines_full_build : List(EngineSpec) -> List(EngineSpec)
engines_full_build = |engines|
    engines.fold([], |acc, e| {
        match e.pipeline {
            FullBuild => List.append(acc, e)
            DumpOnly => acc
        }
    })

primary_engine : List(EngineSpec) -> Try(EngineSpec, [NoPrimaryEngine])
primary_engine = |engines| {
    for e in engines {
        if e.is_primary {
            return Ok(e)
        }
    }
    match List.first(engines) {
        Ok(e) => Ok(e)
        Err(_) => Err(NoPrimaryEngine)
    }
}

zig_argv : EngineSpec, HostTarget, Optimize, Str -> List(Str)
zig_argv = |engine, t, optimize, host_entry| {
    opt = effective_optimize(t, optimize)
    flag = optimize_flag(opt)
    emit = engine_host_out_path(engine, t)

    base : List(Str)
    base =
        match t.kind {
            WasmObj => [
                "build-obj",
                host_entry,
                "-target",
                t.zig_triple,
                flag,
                "-fPIC",
                "-rdynamic",
                "--name",
                "libhost",
                "-femit-bin=${emit}",
            ]
            StaticLib => [
                "build-lib",
                host_entry,
                "-target",
                t.zig_triple,
                flag,
                "-fPIC",
                "-lc",
                "-fcompiler-rt",
                "--name",
                "host",
                "-static",
                "-femit-bin=${emit}",
            ]
        }

    with_strip : List(Str)
    with_strip =
        if opt == Debug {
            base
        } else {
            List.concat(base, ["-fstrip"])
        }

    match t.mcpu {
        NoCpu => with_strip
        Cpu(cpu) => List.concat(with_strip, ["-mcpu", cpu])
    }
}

mk_cmd : NodeId, List(NodeId), Str, List(Str), Str, Str -> _
mk_cmd = |id, depends_on, program, args, description, cwd|
    Build.cmd({
        id: id,
        depends_on: depends_on,
        inputs: [],
        outputs: [],
        program: program,
        args: args,
        description: description,
        cwd: cwd,
        env: [],
    })

# =============================================================================
# Find & replace
# =============================================================================

find_replace_sh_script : Str, List(ReplacePair) -> Str
find_replace_sh_script = |file_path, pairs| {
    header =
        \\set -eu
        \\FILE='${file_path}'
        \\if [ ! -f "$FILE" ]; then
        \\    echo "[find_replace] missing file: $FILE" >&2
        \\    exit 1
        \\fi
        \\
        \\replace_first() {
        \\    _body="$1"
        \\    _find="$2"
        \\    _repl="$3"
        \\    awk -v bodyf="$_body" -v findf="$_find" -v replf="$_repl" '
        \\        function readfile(f,    s, line) {
        \\            s = ""
        \\            while ((getline line < f) > 0)
        \\                s = s line ORS
        \\            close(f)
        \\            return s
        \\        }
        \\        function chomp(s) {
        \\            while (length(s) > 0 && substr(s, length(s), 1) == ORS) {
        \\                s = substr(s, 1, length(s) - 1)
        \\            }
        \\            return s
        \\        }
        \\        BEGIN {
        \\            find = chomp(readfile(findf))
        \\            repl = chomp(readfile(replf))
        \\            body = readfile(bodyf)
        \\            if (length(find) == 0) {
        \\                print "[find_replace] empty find pattern" > "/dev/stderr"
        \\                exit 1
        \\            }
        \\            idx = index(body, find)
        \\            if (idx == 0) {
        \\                print "[find_replace] pattern not found in " bodyf > "/dev/stderr"
        \\                print "[find_replace] find (len=" length(find) "):" > "/dev/stderr"
        \\                print find > "/dev/stderr"
        \\                exit 1
        \\            }
        \\            out = substr(body, 1, idx - 1) repl substr(body, idx + length(find))
        \\            printf "%s", out > bodyf ".new"
        \\        }
        \\    '
        \\    mv "$_body.new" "$_body"
        \\}
        \\

    var $body = header
    var $i = 0.U64
    for pair in pairs {
        tag = $i.to_str()
        $i = $i + 1
        block =
            \\cat >"$FILE.find_${tag}" <<'ENDFIND_${tag}'
            \\${pair.find}
            \\ENDFIND_${tag}
            \\
            \\cat >"$FILE.repl_${tag}" <<'ENDREPL_${tag}'
            \\${pair.replace}
            \\ENDREPL_${tag}
            \\
            \\replace_first "$FILE" "$FILE.find_${tag}" "$FILE.repl_${tag}"
            \\rm -f "$FILE.find_${tag}" "$FILE.repl_${tag}"
            \\
        $body = Str.concat($body, block)
    }

    footer =
        \\printf '%s\n' "patched $FILE"
    Str.concat($body, footer)
}

find_replace_cmd : {
    id : NodeId,
    depends_on : List(NodeId),
    file : Str,
    pairs : List(ReplacePair),
    description : Str,
} -> _
find_replace_cmd = |opts| {
    script = find_replace_sh_script(opts.file, opts.pairs)
    mk_cmd(
        opts.id,
        opts.depends_on,
        "sh",
        ["-c", script],
        opts.description,
        "",
    )
}

# =============================================================================
# Phases
# =============================================================================

phase_prepare : NodeId, List(EngineSpec), List(HostTarget), CiRoots -> _
phase_prepare = |start_id, engines, hosts, roots| {
    var $cmds = []
    var $id = start_id
    var $terminal = []

    clean_roots = [
        roots.smoke_out_root,
        roots.bundle_out_root,
        roots.platform_out_root,
        roots.glue_out_root,
    ]

    var $clean_ids = []
    for root in clean_roots {
        (cid, n) = take_id($id)
        $id = n
        c = mk_cmd(cid, [], "rm", ["-rf", root], "rm -rf ${root}", "")
        $cmds = List.append($cmds, c)
        $clean_ids = List.append($clean_ids, cid)
    }

    var $dirs = [
        roots.smoke_out_root,
        roots.bundle_out_root,
        roots.platform_out_root,
        roots.glue_out_root,
        roots.vendor_out_root,
    ]

    for eng in engines {
        $dirs = List.concat(
            $dirs,
            [
                engine_vendor_dir(eng),
                engine_platform_dir(eng),
                engine_glue_dir(eng),
                engine_smoke_out(eng),
                engine_smoke_workspace(eng),
                engine_bundle_out(eng),
                engine_bundle_workspace(eng),
            ],
        )
        match eng.pipeline {
            FullBuild => {
                for t in hosts {
                    $dirs = List.append($dirs, engine_host_out_dir(eng, t))
                }
            }
            DumpOnly => {}
        }
    }

    var $uniq = []
    for d in $dirs {
        if List.contains($uniq, d) {
            {}
        } else {
            $uniq = List.append($uniq, d)
        }
    }

    for dir in $uniq {
        (mid, n) = take_id($id)
        $id = n
        c = mk_cmd(mid, $clean_ids, "mkdir", ["-p", dir], "mkdir -p ${dir}", "")
        $cmds = List.append($cmds, c)
        $terminal = List.append($terminal, mid)
    }

    {
        cmds: $cmds,
        terminal_ids: $terminal,
        next_id: $id,
    }
}

phase_dump : NodeId, List(NodeId), List(EngineSpec) -> _
phase_dump = |start_id, prepare_ids, engines| {
    var $cmds = []
    var $ids = []
    var $id = start_id

    for eng in engines {
        vendor = engine_vendor_dir(eng)
        for d in eng.dumps {
            (this_id, next) = take_id($id)
            $id = next
            c = mk_cmd(
                this_id,
                prepare_ids,
                d.program,
                d.args,
                d.description,
                vendor,
            )
            $cmds = List.append($cmds, c)
            $ids = List.append($ids, this_id)
        }
    }

    {
        cmds: $cmds,
        terminal_ids: $ids,
        next_id: $id,
    }
}

phase_glue_engine : NodeId, List(NodeId), List(NodeId), EngineSpec, CiRoots -> _
phase_glue_engine = |start_id, prepare_ids, dump_ids, engine, roots| {
    (cp_gde_id, n1) = take_id(start_id)
    (gen_gdext_id, n2) = take_id(n1)
    (test_gdext_id, n3) = take_id(n2)
    (gen_api_id, n4) = take_id(n3)
    (check_plat_id, n5) = take_id(n4)
    (roc_glue_id, n6) = take_id(n5)
    (patch_glue_id, n7) = take_id(n6)
    (test_abi_id, n8) = take_id(n7)
    (test_abi_impl_id, n9) = take_id(n8)

    glue_dir = engine_glue_dir(engine)
    platform_main = engine_platform_main(engine)
    abi_file = engine_abi_file(engine)
    gdext_file = engine_gdext_file(engine)
    gde_call_file = engine_gde_call_file(engine)
    abi_impl_file = engine_abi_impl_file(engine)
    slug = engine.slug
    gate = List.concat(prepare_ids, dump_ids)

    cp_gde_call = mk_cmd(
        cp_gde_id,
        prepare_ids,
        "cp",
        ["host/gde_call.template.zig", gde_call_file],
        "Copy gde_call.zig → ${slug}",
        "",
    )

    gen_gdext = mk_cmd(
        gen_gdext_id,
        gate,
        "roc",
        ["run", "scripts/gdextension_interface.generate.roc", "--", "--engine=${slug}"],
        "Generate gdextension_interface (${slug})",
        "",
    )

    test_gdext = mk_cmd(
        test_gdext_id,
        [gen_gdext_id],
        "zig",
        ["test", gdext_file],
        "zig test gdextension_interface (${slug})",
        "",
    )

    gen_api = mk_cmd(
        gen_api_id,
        gate,
        "roc",
        ["run", "scripts/extension_api.generate.roc", "--", "--engine=${slug}"],
        "Generate extension_api (${slug})",
        "",
    )

    check_plat = mk_cmd(
        check_plat_id,
        [gen_gdext_id, gen_api_id],
        "roc",
        ["check", platform_main],
        "roc check ${platform_main}",
        "",
    )

    roc_glue = mk_cmd(
        roc_glue_id,
        [check_plat_id],
        "roc",
        [
            "glue",
            roots.zig_glue_roc,
            "${glue_dir}/",
            platform_main,
        ],
        "roc glue → ${slug}/roc_platform_abi.zig",
        "",
    )

    patch_glue = find_replace_cmd({
        id: patch_glue_id,
        depends_on: [roc_glue_id],
        file: abi_file,
        pairs: glue_replace_pairs,
        description: "find/replace patch roc_platform_abi.zig (${slug})",
    })

    test_abi = mk_cmd(
        test_abi_id,
        [patch_glue_id],
        "zig",
        ["test", abi_file],
        "zig test roc_platform_abi (${slug})",
        "",
    )

    test_abi_impl = mk_cmd(
        test_abi_impl_id,
        [patch_glue_id, cp_gde_id],
        "zig",
        ["test", abi_impl_file],
        "zig test zig_platform_abi_impl (${slug})",
        "",
    )

    {
        cmds: [
            cp_gde_call,
            gen_gdext,
            test_gdext,
            gen_api,
            check_plat,
            roc_glue,
            patch_glue,
            test_abi,
            test_abi_impl,
        ],
        terminal_ids: [test_gdext_id, test_abi_id, test_abi_impl_id, check_plat_id],
        next_id: n9,
    }
}

phase_hosts_engine : NodeId, List(NodeId), EngineSpec, List(HostTarget), Optimize, CiRoots -> _
phase_hosts_engine = |start_id, glue_ids, engine, selected, optimize, roots| {
    var $cmds = []
    var $build_ids = []
    var $id = start_id
    slug = engine.slug

    for t in selected {
        (this_id, next) = take_id($id)
        $id = next
        argv = zig_argv(engine, t, optimize, roots.host_entry)
        emit = engine_host_out_path(engine, t)
        c = mk_cmd(
            this_id,
            glue_ids,
            "zig",
            argv,
            "compile host ${slug}/${t.name_str} → ${emit}",
            "",
        )
        $cmds = List.append($cmds, c)
        $build_ids = List.append($build_ids, this_id)
    }

    {
        cmds: $cmds,
        terminal_ids: $build_ids,
        next_id: $id,
    }
}

phase_bundle_engine : NodeId, List(NodeId), EngineSpec -> _
phase_bundle_engine = |start_id, host_ids, engine| {
    (copy_plat_id, n1) = take_id(start_id)
    (roc_bundle_id, n2) = take_id(n1)
    (zip_id, n3) = take_id(n2)

    slug = engine.slug
    platform_src = engine_platform_dir(engine)
    platform_dest = engine_bundle_platform_dest(engine)
    bundle_ws = engine_bundle_workspace(engine)
    plat_name = engine_bundle_platform_name(engine)

    rel_main = "${plat_name}/main.roc"
    rel_wasm = "${plat_name}/targets/wasm32/libhost.o.wasm"
    rel_musl = "${plat_name}/targets/x64musl/libhost.a"

    copy_platform = mk_cmd(
        copy_plat_id,
        host_ids,
        "cp",
        ["-a", platform_src, platform_dest],
        "Copy ${platform_src} → ${platform_dest}",
        "",
    )

    roc_bundle = mk_cmd(
        roc_bundle_id,
        [copy_plat_id],
        "roc",
        [
            "bundle",
            rel_main,
            rel_wasm,
            rel_musl,
        ],
        "roc bundle platform (${slug})",
        bundle_ws,
    )

    # Skip empty zip when templates/ is absent under the bundle workspace.
    zip_script =
        \\set -eu
        \\if [ -d templates ]; then
        \\    zip -r templates.zip . -i templates/
        \\else
        \\    echo "[bundle] no templates/ under $(pwd); skipping templates.zip"
        \\fi
        \\

    zip_templates = mk_cmd(
        zip_id,
        [roc_bundle_id],
        "sh",
        ["-c", zip_script],
        "zip templates [${slug}] (optional)",
        bundle_ws,
    )

    {
        cmds: [copy_platform, roc_bundle, zip_templates],
        terminal_ids: [roc_bundle_id, zip_id],
        next_id: n3,
    }
}

phase_workspace_engine : NodeId, List(NodeId), List(NodeId), EngineSpec, CiRoots -> _
phase_workspace_engine = |start_id, prepare_ids, bundle_ids, engine, roots| {
    (copy_id, n1) = take_id(start_id)
    (copy_plat_id, n2) = take_id(n1)
    (patch_id, n3) = take_id(n2)

    project_dir = engine_project_dir(engine)
    project_main = engine_project_main(engine)
    local_plat = engine_project_platform_dir(engine)
    local_plat_main = engine_project_platform_main(engine)
    platform_src = engine_platform_dir(engine)
    slug = engine.slug

    copy_template = mk_cmd(
        copy_id,
        prepare_ids,
        "cp",
        ["-a", "templates/${roots.project_template}", project_dir],
        "Create app \"${roots.project_name}\" → ${project_dir}",
        "",
    )

    copy_script =
        \\set -eu
        \\SRC='${platform_src}'
        \\DST='${local_plat}'
        \\MAIN='${local_plat_main}'
        \\if [ ! -d "$SRC" ]; then
        \\    echo "[workspace] missing platform source: $SRC" >&2
        \\    exit 1
        \\fi
        \\if [ ! -f "$SRC/main.roc" ]; then
        \\    echo "[workspace] missing $SRC/main.roc" >&2
        \\    ls -la "$SRC" >&2 || true
        \\    exit 1
        \\fi
        \\rm -rf "$DST"
        \\cp -a "$SRC" "$DST"
        \\if [ ! -f "$MAIN" ]; then
        \\    echo "[workspace] copy failed; missing $MAIN" >&2
        \\    ls -la "$DST" >&2 || true
        \\    exit 1
        \\fi
        \\echo "[workspace] local platform ready: $MAIN"
        \\

    copy_local_platform = mk_cmd(
        copy_plat_id,
        List.concat(bundle_ids, [copy_id]),
        "sh",
        ["-c", copy_script],
        "Install local platform → ${local_plat} (${slug})",
        "",
    )

    patch_platform = find_replace_cmd({
        id: patch_id,
        depends_on: [copy_plat_id],
        file: project_main,
        pairs: [
            {
                find: "pf: platform \"[PLATFORM_GOES_HERE]\",",
                replace: "pf: platform \"${engine_local_platform_pkg}\",",
            },
        ],
        description: "Patch platform → ${engine_local_platform_pkg} (${slug})",
    })

    {
        cmds: [copy_template, copy_local_platform, patch_platform],
        terminal_ids: [patch_id],
        next_id: n3,
    }
}

phase_game_engine : {
    start_id : NodeId,
    host_ids : List(NodeId),
    template_ids : List(NodeId),
    engine : EngineSpec,
    deep_wasm : Bool,
} -> _
phase_game_engine = |p| {
    eng = p.engine
    slug = eng.slug
    project_dir = engine_project_dir(eng)
    project_main = engine_project_main(eng)
    linux_out = engine_project_linux_out(eng)
    temp_a = engine_project_temp_a(eng)
    wasm_out = engine_project_wasm(eng)

    (linux_id, n1) = take_id(p.start_id)
    (web_id, n2) = take_id(n1)
    (ar_id, n3) = take_id(n2)
    (val_host_id, n4) = take_id(n3)
    (val_app_obj_id, n5) = take_id(n4)
    (wasm_ld_id, n6) = take_id(n5)
    (emcc_id, n7) = take_id(n6)
    (val_final_id, n8) = take_id(n7)
    (export_id, n9) = take_id(n8)

    game_deps = List.concat(p.host_ids, p.template_ids)

    roc_linux = mk_cmd(
        linux_id,
        game_deps,
        "roc",
        [
            "build",
            project_main,
            "--target=x64musl",
            "--no-cache",
            "--output=${linux_out}",
        ],
        "Compiling desktop roc game (x64musl, ${slug})",
        "",
    )

    roc_web = mk_cmd(
        web_id,
        game_deps,
        "roc",
        [
            "build",
            project_main,
            "--target=wasm32",
            "--output=${temp_a}",
        ],
        "Compiling web roc game (wasm32, ${slug})",
        "",
    )

    ar_x = mk_cmd(
        ar_id,
        [web_id],
        "ar",
        ["x", temp_a, "--output", project_dir],
        "Extracting for validation (ar x) [${slug}]",
        "",
    )

    validate_host = mk_cmd(
        val_host_id,
        [ar_id],
        "wasm-validate",
        ["${project_dir}/libhost.o.wasm"],
        "wasm-validate libhost.o.wasm [${slug}]",
        "",
    )

    validate_app_obj = mk_cmd(
        val_app_obj_id,
        [ar_id],
        "wasm-validate",
        ["${project_dir}/roc_app_llvm_wasm32_speed.o"],
        "wasm-validate roc_app_llvm_wasm32_speed.o [${slug}]",
        "",
    )

    wasm_ld = mk_cmd(
        wasm_ld_id,
        [val_host_id, val_app_obj_id],
        "zig",
        [
            "wasm-ld",
            "--fatal-warnings",
            "--experimental-pic",
            "--no-entry",
            "--export-dynamic",
            "--import-memory",
            "--import-table",
            "-shared",
            "-o",
            "${project_dir}/test.wasm",
            "${project_dir}/libhost.o.wasm",
            "${project_dir}/roc_app_llvm_wasm32_speed.o",
        ],
        "Linking with wasm-ld (diagnostic) [${slug}]",
        "",
    )

    emcc = mk_cmd(
        emcc_id,
        [web_id],
        "emcc",
        [
            temp_a,
            "-o",
            wasm_out,
            "-sERROR_ON_UNDEFINED_SYMBOLS=1",
            "-sSIDE_MODULE=2",
            "-sEXPORTED_FUNCTIONS=_godot_roc_init",
            "-O0",
            "-msimd128",
        ],
        "Final Web GDExtension (emcc SIDE_MODULE=2) [${slug}]",
        "",
    )

    validate_final = mk_cmd(
        val_final_id,
        [emcc_id],
        "wasm-validate",
        ["--enable-extended-const", wasm_out],
        "wasm-validate final game wasm [${slug}]",
        "",
    )

    # Primary only: needs matching export templates (4.7.2 in current nix env).
    # Artifact-gated: success if export/index.html exists even when engine crashes after pack.
    export_script =
        \\set +e
        \\ENGINE='${eng.program}'
        \\PROJECT='project.godot'
        \\OUT='export/index.html'
        \\ARTIFACT='export/index.html'
        \\if [ ! -f "$PROJECT" ]; then
        \\    echo "[ci] missing $PROJECT in $(pwd)" >&2
        \\    ls -la >&2 || true
        \\    exit 1
        \\fi
        \\if [ ! -f export_presets.cfg ]; then
        \\    echo "[ci] missing export_presets.cfg (need a preset named Web)" >&2
        \\    exit 1
        \\fi
        \\mkdir -p export
        \\"$ENGINE" --path . --headless --export-release "Web" "$OUT"
        \\status=$?
        \\if [ -f "$ARTIFACT" ]; then
        \\    echo "[ci] export artifact ok: $(pwd)/$ARTIFACT (engine exit=$status)"
        \\    exit 0
        \\fi
        \\echo "[ci] export failed: missing $(pwd)/$ARTIFACT (engine exit=$status)" >&2
        \\ls -la export >&2 || true
        \\exit 1
        \\

    skip_export_script =
        \\echo "[ci] skip Web export for ${slug} (no matching export templates in this environment)"
        \\exit 0
        \\

    godot_export =
        if eng.export_web {
            mk_cmd(
                export_id,
                [val_final_id, linux_id],
                "sh",
                ["-c", export_script],
                "Web export (${slug}) — artifact-gated",
                project_dir,
            )
        } else {
            mk_cmd(
                export_id,
                [val_final_id, linux_id],
                "sh",
                ["-c", skip_export_script],
                "Skip Web export (${slug})",
                project_dir,
            )
        }

    base_cmds = [
        roc_linux,
        roc_web,
        ar_x,
        validate_host,
        validate_app_obj,
        emcc,
        validate_final,
        godot_export,
    ]

    cmds =
        if p.deep_wasm {
            List.concat(base_cmds, [wasm_ld])
        } else {
            base_cmds
        }

    {
        cmds: cmds,
        terminal_ids: [export_id, linux_id],
        next_id: n9,
    }
}

phase_publish : NodeId, List(NodeId), List(EngineSpec), PublishOpts -> _
phase_publish = |start_id, depends_on, build_engines, opts| {
    if !opts.enabled {
        {
            cmds: [],
            terminal_ids: [],
            next_id: start_id,
        }
    } else {
        (pub_id, n1) = take_id(start_id)

        var $asset_args = ""
        for eng in build_engines {
            $asset_args = Str.concat($asset_args, " bundle-out/${eng.slug}")
        }

        tag_line =
            if opts.tag == "" {
                "TAG=\"ci-$(date -u +%Y%m%d-%H%M%S)\"\n"
            } else {
                "TAG=\"${opts.tag}\"\n"
            }

        token_line =
            if opts.token == "" {
                ""
            } else {
                "export GITHUB_TOKEN=\"${opts.token}\"\n"
            }

        script =
            Str.concat(
                "set -eu\n",
                Str.concat(
                    token_line,
                    Str.concat(
                        "if [ -z \"$GITHUB_TOKEN\" ]; then\n",
                        Str.concat(
                            "  echo \"[publish] GITHUB_TOKEN or --github-token= required\" >&2\n",
                            Str.concat(
                                "  exit 1\n",
                                Str.concat(
                                    "fi\n",
                                    Str.concat(
                                        "if ! command -v gh >/dev/null 2>&1; then\n",
                                        Str.concat(
                                            "  echo \"[publish] GitHub CLI (gh) not found\" >&2\n",
                                            Str.concat(
                                                "  exit 1\n",
                                                Str.concat(
                                                    "fi\n",
                                                    Str.concat(
                                                        tag_line,
                                                        Str.concat(
                                                            "echo \"[publish] creating release $TAG\"\n",
                                                            Str.concat(
                                                                "gh release create \"$TAG\"",
                                                                Str.concat(
                                                                    $asset_args,
                                                                    " --title \"godot-roc $TAG\" --notes \"Automated CI artefacts (platform bundles per engine).\"\n",
                                                                ),
                                                            ),
                                                        ),
                                                    ),
                                                ),
                                            ),
                                        ),
                                    ),
                                ),
                            ),
                        ),
                    ),
                ),
            )

        pub = mk_cmd(
            pub_id,
            depends_on,
            "sh",
            ["-c", script],
            "GitHub release publish (bundle-out/*)",
            "",
        )

        {
            cmds: [pub],
            terminal_ids: [pub_id],
            next_id: n1,
        }
    }
}

# =============================================================================
# Entry
# =============================================================================

main! : List(Str) => Try({}, [Exit(I32)])
main! = |args| {
    user_args =
        if List.is_empty(args) {
            []
        } else {
            List.drop_first(args, 1)
        }

    optimize = parse_optimize(user_args)
    mode = parse_mode(user_args)
    deep_wasm = List.contains(user_args, "deep-wasm") or mode == Full
    publish_opts = parse_publish(user_args)

    Log.info!("CI — engine × host matrix")
    Log.info!("mode=${mode_label(mode)}  host_optimize=${optimize_label(optimize)}  deep_wasm=${if deep_wasm "yes" else "no"}")
    Log.info!("publish=${if publish_opts.enabled "yes" else "no"}")

    roots = default_roots
    engines = select_engines(mode)
    build_engines = engines_full_build(engines)
    selected_hosts = with_baselines(select_hosts(mode))

    Log.info!("engines (${List.len(engines).to_str()}):")
    for e in engines {
        web =
            if e.export_web {
                "web-export"
            } else {
                "no-web-export"
            }
        Log.info!("  - ${e.slug} [${pipeline_label(e.pipeline)}, ${web}]")
    }
    Log.info!("host targets (${List.len(selected_hosts).to_str()}):")
    for t in selected_hosts {
        Log.info!("  - ${t.name_str}")
    }

    match primary_engine(build_engines) {
        Err(NoPrimaryEngine) => {
            Log.error!("No FullBuild primary engine selected")
            Err(Exit(1))
        }
        Ok(_primary) => {
            prep = phase_prepare(0, engines, selected_hosts, roots)
            dump = phase_dump(prep.next_id, prep.terminal_ids, engines)

            var $cmds = List.concat(prep.cmds, dump.cmds)
            var $id = dump.next_id
            var $all_terminals = []

            for eng in build_engines {
                g = phase_glue_engine($id, prep.terminal_ids, dump.terminal_ids, eng, roots)
                $cmds = List.concat($cmds, g.cmds)
                $id = g.next_id

                h = phase_hosts_engine($id, g.terminal_ids, eng, selected_hosts, optimize, roots)
                $cmds = List.concat($cmds, h.cmds)
                $id = h.next_id

                b = phase_bundle_engine($id, h.terminal_ids, eng)
                $cmds = List.concat($cmds, b.cmds)
                $id = b.next_id

                ws = phase_workspace_engine($id, prep.terminal_ids, b.terminal_ids, eng, roots)
                $cmds = List.concat($cmds, ws.cmds)
                $id = ws.next_id

                game = phase_game_engine({
                    start_id: $id,
                    host_ids: h.terminal_ids,
                    template_ids: ws.terminal_ids,
                    engine: eng,
                    deep_wasm: deep_wasm,
                })
                $cmds = List.concat($cmds, game.cmds)
                $id = game.next_id
                $all_terminals = List.concat($all_terminals, game.terminal_ids)
            }

            pub = phase_publish($id, $all_terminals, build_engines, publish_opts)
            $cmds = List.concat($cmds, pub.cmds)

            graph = Build.graph($cmds)

            match Build.run!(graph) {
                Ok({}) => {
                    Log.info!("all tasks finished")
                    for eng in build_engines {
                        Log.info!("engine ${eng.slug}:")
                        Log.info!("  CI app:  ${engine_project_dir(eng)}")
                        Log.info!("  local platform: ${engine_project_platform_main(eng)}")
                        Log.info!("  Bundle:  ${engine_bundle_workspace(eng)}")
                        if eng.export_web {
                            Log.info!("  Export:  ${engine_export_index(eng)}")
                        } else {
                            Log.info!("  Export:  (skipped — no templates for this engine)")
                        }
                    }
                    match primary_engine(build_engines) {
                        Ok(p) => {
                            Log.info!("Editor test (primary):")
                            Log.info!("  ${p.program} ${engine_project_godot(p)}")
                            Log.info!("Web:")
                            Log.info!("  SERVE_PATH='${engine_project_dir(p)}/export' roc run scripts/serve.roc")
                        }
                        Err(_) => {}
                    }
                    Ok({})
                }
                Err(BuildFailed(msg)) => {
                    Log.error!(msg)
                    Err(Exit(1))
                }
            }
        }
    }
}
