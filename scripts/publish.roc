#!/usr/bin/env roc

#
# Publish platform bundles (no smoke / workspace / game).
# Zig host compiles are sequential (one at a time) to bound RAM.
#
# Defaults:
#   --baseline=godot4.5
#   --engines=godot-latest,redot-latest
#   --targets=all
#   -Doptimize=ReleaseFast
#   --tag=  → nightly-YYYY-MM-DD-<sha7> if omitted
#
# Examples:
#   roc run scripts/publish.roc -- \
#     --baseline=godot4.5 --engines=godot-latest,redot-latest \
#     --targets=x64musl,wasm32 -Doptimize=ReleaseFast \
#     --tag=nightly-2026-10-11-abc1234
#
#   roc run scripts/publish.roc -- \
#     --baseline=godot4.5 --engines=godot-latest,redot-latest \
#     --tag=v0.1.0-rc1 -Doptimize=ReleaseFast
#

app [main!] {
    pf: platform "https://github.com/scottc/roc-build/releases/download/v0.0.5-alpha/5YqLuJixx2M3z6GcQN666sSVW2TXZkDt52Ny7V67poSD.tar.zst",
}

import pf.Build
import pf.Log

# =============================================================================
# Types
# =============================================================================

Optimize : [Debug, ReleaseFast, ReleaseSafe, ReleaseSmall]

LibKind : [StaticLib, WasmObj]

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
}

EngineName : [Godot, Godot451, Redot]

EngineSpec : {
    name : EngineName,
    slug : Str,
    cli_id : Str,
    program : Str,
}

PublishOpts : {
    tag : [AutoTag, Tag(Str)],
}

PubConfig : {
    baseline : EngineSpec,
    engines : List(EngineSpec),
    hosts : List(HostTarget),
    optimize : Optimize,
    publish : PublishOpts,
}

NodeId : U64

PhaseResult : {
    cmds : List(Build.Cmd),
    terminal_ids : List(NodeId),
    next_id : NodeId,
}

ReplacePair : { find : Str, replace : Str }

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
    },
    {
        name: X64Musl,
        name_str: "x64musl",
        zig_triple: "x86_64-linux-musl",
        kind: StaticLib,
        lib_file: "libhost.a",
        mcpu: NoCpu,
    },
    {
        name: X64V1Musl,
        name_str: "x64v1musl",
        zig_triple: "x86_64-linux-musl",
        kind: StaticLib,
        lib_file: "libhost.a",
        mcpu: Cpu("x86_64"),
    },
    {
        name: Arm64Musl,
        name_str: "arm64musl",
        zig_triple: "aarch64-linux-musl",
        kind: StaticLib,
        lib_file: "libhost.a",
        mcpu: NoCpu,
    },
    {
        name: Arm64V1Musl,
        name_str: "arm64v1musl",
        zig_triple: "aarch64-linux-musl",
        kind: StaticLib,
        lib_file: "libhost.a",
        mcpu: Cpu("baseline"),
    },
    {
        name: X64Mac,
        name_str: "x64mac",
        zig_triple: "x86_64-macos",
        kind: StaticLib,
        lib_file: "libhost.a",
        mcpu: NoCpu,
    },
    {
        name: Arm64Mac,
        name_str: "arm64mac",
        zig_triple: "aarch64-macos",
        kind: StaticLib,
        lib_file: "libhost.a",
        mcpu: NoCpu,
    },
    {
        name: X64Win,
        name_str: "x64win",
        zig_triple: "x86_64-windows",
        kind: StaticLib,
        lib_file: "host.lib",
        mcpu: NoCpu,
    },
    {
        name: X64Mingw,
        name_str: "x64mingw",
        zig_triple: "x86_64-windows-gnu",
        kind: StaticLib,
        lib_file: "host.lib",
        mcpu: NoCpu,
    },
    {
        name: Arm64Win,
        name_str: "arm64win",
        zig_triple: "aarch64-windows",
        kind: StaticLib,
        lib_file: "host.lib",
        mcpu: NoCpu,
    },
    {
        name: Arm64Mingw,
        name_str: "arm64mingw",
        zig_triple: "aarch64-windows-gnu",
        kind: StaticLib,
        lib_file: "host.lib",
        mcpu: NoCpu,
    },
]

engine_specs : List(EngineSpec)
engine_specs = [
    {
        name: Godot,
        slug: "godot",
        cli_id: "godot",
        program: "godot",
    },
    {
        name: Godot451,
        slug: "godot4_5",
        cli_id: "godot4.5",
        program: "godot4.5",
    },
    {
        name: Redot,
        slug: "redot",
        cli_id: "redot",
        program: "redot",
    },
]

glue_spec : Str
glue_spec = "vendor/roc/nightly-2026-09-27-a3ce7f1/ZigGlue.roc"

# =============================================================================
# CLI
# =============================================================================

flag_value : List(Str), Str -> [None, Some(Str)]
flag_value = |args, prefix| {
    for a in args {
        if a.starts_with(prefix) {
            return Some(a.drop_prefix(prefix))
        }
    }
    None
}

parse_optimize : List(Str) -> Optimize
parse_optimize = |args| {
    match flag_value(args, "-Doptimize=") {
        Some("Debug") => Debug
        Some("ReleaseFast") => ReleaseFast
        Some("ReleaseSafe") => ReleaseSafe
        Some("ReleaseSmall") => ReleaseSmall
        _ => ReleaseFast
    }
}

parse_engine_id : Str -> [Ok(EngineName), Err(Str)]
parse_engine_id = |id| {
    match id {
        "godot" | "godot-latest" => Ok(Godot)
        "godot4.5" | "godot4.5.1" | "godot4_5" => Ok(Godot451)
        "redot" | "redot-latest" => Ok(Redot)
        _ => Err(id)
    }
}

engine_by_name : EngineName -> EngineSpec
engine_by_name = |n| {
    for e in engine_specs {
        if e.name == n {
            return e
        }
    }
    {
        name: Godot451,
        slug: "godot4_5",
        cli_id: "godot4.5",
        program: "godot4.5",
    }
}

parse_baseline : List(Str) -> EngineSpec
parse_baseline = |args| {
    match flag_value(args, "--baseline=") {
        Some(id) =>
            match parse_engine_id(id) {
                Ok(n) => engine_by_name(n)
                Err(_) => engine_by_name(Godot451)
            }
        None => engine_by_name(Godot451)
    }
}

split_comma : Str -> List(Str)
split_comma = |s| {
    bytes = s.to_utf8()
    var $acc = []
    var $cur = []
    for b in bytes {
        if b == 44.U8 {
            part =
                match Str.from_utf8($cur) {
                    Ok(p) => p.trim()
                    Err(_) => ""
                }
            if !part.is_empty() {
                $acc = $acc.append(part)
            }
            $cur = []
        } else {
            $cur = $cur.append(b)
        }
    }
    last =
        match Str.from_utf8($cur) {
            Ok(p) => p.trim()
            Err(_) => ""
        }
    if !last.is_empty() {
        $acc = $acc.append(last)
    }
    $acc
}

parse_engines : List(Str), EngineSpec -> List(EngineSpec)
parse_engines = |args, baseline| {
    match flag_value(args, "--engines=") {
        Some("none") => [baseline]
        Some(raw) => {
            var $out = [baseline]
            for id in split_comma(raw) {
                match parse_engine_id(id) {
                    Ok(n) => {
                        extra = engine_by_name(n)
                        var $dup = Bool.False
                        for e in $out {
                            if e.name == extra.name {
                                $dup = Bool.True
                            }
                        }
                        if !$dup {
                            $out = $out.append(extra)
                        }
                    }
                    Err(_) => {}
                }
            }
            $out
        }
        None => [
            baseline,
            engine_by_name(Godot),
            engine_by_name(Redot),
        ]
    }
}

parse_targets : List(Str) -> List(HostTarget)
parse_targets = |args| {
    match flag_value(args, "--targets=") {
        Some("all") => host_targets
        Some("auto") | None => {
            # Default publish targets: x64musl + wasm32
            var $out = []
            for h in host_targets {
                if h.name_str == "wasm32" or h.name_str == "x64musl" {
                    $out = $out.append(h)
                }
            }
            $out
        }
        Some(raw) => {
            names = split_comma(raw)
            var $out = []
            for h in host_targets {
                for n in names {
                    if h.name_str == n {
                        $out = $out.append(h)
                    }
                }
            }
            if $out.len() == 0 {
                var $fallback = []
                for h in host_targets {
                    if h.name_str == "wasm32" or h.name_str == "x64musl" {
                        $fallback = $fallback.append(h)
                    }
                }
                $fallback
            } else {
                $out
            }
        }
    }
}

parse_tag : List(Str) -> [AutoTag, Tag(Str)]
parse_tag = |args| {
    match flag_value(args, "--tag=") {
        Some(t) => Tag(t)
        None => AutoTag
    }
}

parse_config : List(Str) -> PubConfig
parse_config = |args| {
    baseline = parse_baseline(args)
    {
        baseline,
        engines: parse_engines(args, baseline),
        hosts: parse_targets(args),
        optimize: parse_optimize(args),
        publish: { tag: parse_tag(args) },
    }
}

# =============================================================================
# Paths
# =============================================================================

engine_dump_dir : EngineSpec -> Str
engine_dump_dir = |e| "dump-out/${e.slug}"

engine_platform_dir : EngineSpec -> Str
engine_platform_dir = |e| "platform-out/${e.slug}"

engine_glue_dir : EngineSpec -> Str
engine_glue_dir = |e| "host/glue-out/${e.slug}"

engine_bundle_dir : EngineSpec -> Str
engine_bundle_dir = |e| "bundle-out/${e.slug}"

## Human-readable engine label for release notes / asset names
engine_label : EngineSpec -> Str
engine_label = |e| {
    match e.name {
        Godot => "godot (latest)"
        Godot451 => "godot4.5 (baseline)"
        Redot => "redot (latest)"
    }
}

optimize_str : Optimize -> Str
optimize_str = |o| {
    match o {
        Debug => "Debug"
        ReleaseFast => "ReleaseFast"
        ReleaseSafe => "ReleaseSafe"
        ReleaseSmall => "ReleaseSmall"
    }
}

# =============================================================================
# Shell helpers
# =============================================================================

sh_dollar_brace : Str -> Str
sh_dollar_brace = |inner| Str.concat("$", Str.concat("{", Str.concat(inner, "}")))

find_replace_sh_script : Str, List(ReplacePair) -> Str
find_replace_sh_script = |file, pairs| {
    var $parts = [
        "set -eu\n",
        "FILE='",
        file,
        "'\n",
        "if [ ! -f \"$FILE\" ]; then\n",
        "  echo \"[find_replace] missing file: $FILE\" >&2\n",
        "  exit 1\n",
        "fi\n",
        "replace_first() {\n",
        "  _body=\"$1\"\n",
        "  _find=\"$2\"\n",
        "  _repl=\"$3\"\n",
        "  awk -v bodyf=\"$_body\" -v findf=\"$_find\" -v replf=\"$_repl\" '\n",
        "    function readfile(f,    s, line) {\n",
        "      s = \"\"\n",
        "      while ((getline line < f) > 0)\n",
        "        s = s line ORS\n",
        "      close(f)\n",
        "      return s\n",
        "    }\n",
        "    BEGIN {\n",
        "      find = readfile(findf)\n",
        "      repl = readfile(replf)\n",
        "      body = readfile(bodyf)\n",
        "      while (length(body) > 0 && substr(body, length(body), 1) == ORS)\n",
        "        body = substr(body, 1, length(body) - 1)\n",
        "      while (length(find) > 0 && substr(find, length(find), 1) == ORS)\n",
        "        find = substr(find, 1, length(find) - 1)\n",
        "      while (length(repl) > 0 && substr(repl, length(repl), 1) == ORS)\n",
        "        repl = substr(repl, 1, length(repl) - 1)\n",
        "      idx = index(body, find)\n",
        "      if (idx == 0) {\n",
        "        print \"[find_replace] pattern not found in \" bodyf > \"/dev/stderr\"\n",
        "        exit 1\n",
        "      }\n",
        "      out = substr(body, 1, idx - 1) repl substr(body, idx + length(find))\n",
        "      printf \"%s\", out > bodyf \".new\"\n",
        "    }\n",
        "  '\n",
        "  mv \"$_body.new\" \"$_body\"\n",
        "}\n",
    ]
    var $i = 0.U64
    for p in pairs {
        i_str = $i.to_str()
        $parts = List.concat(
            $parts,
            [
                "cat >\"$FILE.find_",
                i_str,
                "\" <<'ENDFIND'\n",
                p.find,
                "\nENDFIND\n",
                "cat >\"$FILE.repl_",
                i_str,
                "\" <<'ENDREPL'\n",
                p.replace,
                "\nENDREPL\n",
                "replace_first \"$FILE\" \"$FILE.find_",
                i_str,
                "\" \"$FILE.repl_",
                i_str,
                "\"\n",
                "rm -f \"$FILE.find_",
                i_str,
                "\" \"$FILE.repl_",
                i_str,
                "\"\n",
            ],
        )
        $i = $i + 1
    }
    $parts = List.concat($parts, ["printf '%s\\n' \"patched $FILE\"\n"])
    Str.join_with($parts, "")
}

find_replace_cmd : NodeId, List(NodeId), Str, List(ReplacePair), Str -> Build.Cmd
find_replace_cmd = |id, depends_on, file, pairs, description| {
    script = find_replace_sh_script(file, pairs)
    Build.cmd({
        id,
        depends_on,
        inputs: [file],
        outputs: [file],
        program: "sh",
        args: ["-c", script],
        description,
        cwd: "",
        env: [],
    })
}

# =============================================================================
# Phases
# =============================================================================

phase_prepare : NodeId, List(EngineSpec) -> PhaseResult
phase_prepare = |start_id, engines| {
    var $id = start_id
    var $cmds = []
    var $clean_ids = []

    roots = ["dump-out", "platform-out", "host/glue-out", "bundle-out", "release-assets"]
    for r in roots {
        c = Build.cmd({
            id: $id,
            depends_on: [],
            inputs: [],
            outputs: [],
            program: "rm",
            args: ["-rf", r],
            description: "rm -rf ${r}",
            cwd: "",
            env: [],
        })
        $cmds = $cmds.append(c)
        $clean_ids = $clean_ids.append($id)
        $id = $id + 1
    }

    var $terminals = []
    for e in engines {
        dirs = [
            engine_dump_dir(e),
            engine_platform_dir(e),
            "${engine_platform_dir(e)}/targets",
            engine_glue_dir(e),
            engine_bundle_dir(e),
        ]
        for d in dirs {
            c = Build.cmd({
                id: $id,
                depends_on: $clean_ids,
                inputs: [],
                outputs: [],
                program: "mkdir",
                args: ["-p", d],
                description: "mkdir -p ${d}",
                cwd: "",
                env: [],
            })
            $cmds = $cmds.append(c)
            $terminals = $terminals.append($id)
            $id = $id + 1
        }
    }

    { cmds: $cmds, terminal_ids: $terminals, next_id: $id }
}

phase_dump : NodeId, List(NodeId), EngineSpec -> PhaseResult
phase_dump = |start_id, prepare_ids, eng| {
    dump_dir = engine_dump_dir(eng)
    dump = Build.cmd({
        id: start_id,
        depends_on: prepare_ids,
        inputs: [],
        outputs: [
            "${dump_dir}/gdextension_interface.h",
            "${dump_dir}/extension_api.json",
        ],
        program: eng.program,
        args: ["--headless", "--dump-gdextension-interface", "--dump-extension-api"],
        description: "dump (${eng.slug})",
        cwd: dump_dir,
        env: [],
    })
    { cmds: [dump], terminal_ids: [start_id], next_id: start_id + 1 }
}

phase_glue_engine : NodeId, List(NodeId), List(NodeId), EngineSpec, List(HostTarget) -> PhaseResult
phase_glue_engine = |start_id, prepare_ids, dump_ids, eng, hosts| {
    slug = eng.slug
    glue_dir = engine_glue_dir(eng)
    platform_dir = engine_platform_dir(eng)
    var $id = start_id
    var $cmds = []
    deps = List.concat(prepare_ids, dump_ids)

    gen_iface = Build.cmd({
        id: $id,
        depends_on: deps,
        inputs: ["${engine_dump_dir(eng)}/gdextension_interface.h"],
        outputs: ["${glue_dir}/gdextension_interface.zig"],
        program: "roc",
        args: [
            "run",
            "scripts/gdextension_interface.generate.roc",
            "--",
            "--engine=${slug}",
        ],
        description: "Generate gdextension_interface (${slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(gen_iface)
    gen_iface_id = $id
    $id = $id + 1

    gen_api = Build.cmd({
        id: $id,
        depends_on: deps,
        inputs: ["${engine_dump_dir(eng)}/extension_api.json"],
        outputs: [
            "${platform_dir}/main.roc",
            "${glue_dir}/zig_platform_abi_impl.zig",
        ],
        program: "roc",
        args: [
            "run",
            "scripts/extension_api.generate.roc",
            "--",
            "--engine=${slug}",
            "--targets=${Str.join_with(hosts.map(|h| h.name_str), ",")}",
        ],
        description: "Generate extension_api platform (${slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(gen_api)
    gen_api_id = $id
    $id = $id + 1

    glue = Build.cmd({
        id: $id,
        depends_on: [gen_api_id],
        inputs: [glue_spec, "${platform_dir}/main.roc"],
        outputs: ["${glue_dir}/roc_platform_abi.zig"],
        program: "roc",
        args: [
            "glue",
            glue_spec,
            glue_dir,
            "${platform_dir}/main.roc",
        ],
        description: "roc glue (${slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(glue)
    glue_id = $id
    $id = $id + 1

    patch = find_replace_cmd(
        $id,
        [glue_id],
        "${glue_dir}/roc_platform_abi.zig",
        [
            {
                find: "fn nativeWriteStderr",
                replace:
                    \\fn nativeWriteStderr(_: ?*anyopaque, data: []const u8) void {
                    \\    _ = data;
                    \\}
                    \\fn nativeWriteStderr_PATCHED_MARKER
            },
        ],
        "patch glue marker (${slug})",
    )
    $cmds = $cmds.append(patch)
    patch_id = $id
    $id = $id + 1

    abi_note = Build.cmd({
        id: $id,
        depends_on: [patch_id],
        inputs: ["${glue_dir}/roc_platform_abi.zig"],
        outputs: ["${glue_dir}/roc_platform_abi.zig"],
        program: "sh",
        args: [
            "-c",
            Str.join_with(
                [
                    "set -eu\n",
                    "F='",
                    glue_dir,
                    "/roc_platform_abi.zig'\n",
                    "if [ ! -f \"$F\" ]; then echo missing \"$F\" >&2; exit 1; fi\n",
                    "grep -q 'PATCHED BY scripts/publish.roc' \"$F\" || printf '\\n// PATCHED BY scripts/publish.roc (glue)\\n' >> \"$F\"\n",
                ],
                "",
            ),
        ],
        description: "note patched glue (${slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(abi_note)
    abi_id = $id
    $id = $id + 1

    cp_gde = Build.cmd({
        id: $id,
        depends_on: [gen_iface_id],
        inputs: ["host/gde_call.template.zig"],
        outputs: ["${glue_dir}/gde_call.zig"],
        program: "cp",
        args: ["host/gde_call.template.zig", "${glue_dir}/gde_call.zig"],
        description: "cp gde_call.zig (${slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(cp_gde)
    cp_id = $id
    $id = $id + 1

    zt = Build.cmd({
        id: $id,
        depends_on: [gen_iface_id],
        inputs: ["${glue_dir}/gdextension_interface.zig"],
        outputs: [],
        program: "zig",
        args: ["test", "${glue_dir}/gdextension_interface.zig"],
        description: "zig test gdextension_interface (${slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(zt)
    zt_id = $id
    $id = $id + 1

    rc = Build.cmd({
        id: $id,
        depends_on: [gen_api_id],
        inputs: ["${platform_dir}/main.roc"],
        outputs: [],
        program: "roc",
        args: ["check", "${platform_dir}/main.roc"],
        description: "roc check platform (${slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(rc)
    rc_id = $id
    $id = $id + 1

    {
        cmds: $cmds,
        terminal_ids: [abi_id, cp_id, zt_id, rc_id],
        next_id: $id,
    }
}

zig_host_args : HostTarget, Optimize, Str -> List(Str)
zig_host_args = |host, opt, out_path| {
    o = optimize_str(opt)
    base =
        match host.kind {
            WasmObj =>
                [
                    "build-obj",
                    "host/host.zig",
                    "-target",
                    host.zig_triple,
                    "-O${o}",
                    "-fPIC",
                    "-fcompiler-rt",
                    "--name",
                    "host",
                    "-femit-bin=${out_path}",
                ]
            StaticLib =>
                [
                    "build-lib",
                    "host/host.zig",
                    "-target",
                    host.zig_triple,
                    "-O${o}",
                    "-fPIC",
                    "-lc",
                    "-fcompiler-rt",
                    "--name",
                    "host",
                    "-static",
                    "-femit-bin=${out_path}",
                ]
        }
    match host.mcpu {
        Cpu(c) => List.concat(base, ["-mcpu=${c}"])
        NoCpu => base
    }
}

## Sequential Zig host compiles (one at a time).
phase_hosts_engine : NodeId, List(NodeId), List(NodeId), EngineSpec, List(HostTarget), Optimize -> PhaseResult
phase_hosts_engine = |start_id, glue_ids, prior_ids, eng, hosts, opt| {
    var $id = start_id
    var $cmds = []
    var $prev = List.concat(glue_ids, prior_ids)
    var $last = $prev

    for h in hosts {
        out_dir = "${engine_platform_dir(eng)}/targets/${h.name_str}"
        out_path = "${out_dir}/${h.lib_file}"

        mk = Build.cmd({
            id: $id,
            depends_on: $prev,
            inputs: [],
            outputs: [],
            program: "mkdir",
            args: ["-p", out_dir],
            description: "mkdir host target ${eng.slug}/${h.name_str}",
            cwd: "",
            env: [],
        })
        $cmds = $cmds.append(mk)
        mk_id = $id
        $id = $id + 1

        c = Build.cmd({
            id: $id,
            depends_on: [mk_id],
            inputs: ["host/host.zig"],
            outputs: [out_path],
            program: "zig",
            args: zig_host_args(h, opt, out_path),
            description: "compile host ${eng.slug}/${h.name_str}",
            cwd: "",
            env: [],
        })
        $cmds = $cmds.append(c)
        $prev = [$id]
        $last = [$id]
        $id = $id + 1
    }

    { cmds: $cmds, terminal_ids: $last, next_id: $id }
}

phase_bundle_engine : NodeId, List(NodeId), EngineSpec, List(HostTarget) -> PhaseResult
phase_bundle_engine = |start_id, host_ids, eng, hosts| {
    var $id = start_id
    var $cmds = []
    plat = engine_platform_dir(eng)

    mk = Build.cmd({
        id: $id,
        depends_on: host_ids,
        inputs: [],
        outputs: [],
        program: "mkdir",
        args: ["-p", engine_bundle_dir(eng)],
        description: "mkdir bundle-out (${eng.slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(mk)
    mk_id = $id
    $id = $id + 1

    var $bundle_args = ["bundle", "main.roc"]
    for h in hosts {
        $bundle_args = $bundle_args.append("targets/${h.name_str}/${h.lib_file}")
    }

    bund = Build.cmd({
        id: $id,
        depends_on: [mk_id],
        inputs: ["${plat}/main.roc"],
        outputs: [],
        program: "roc",
        args: $bundle_args,
        description: "roc bundle (${eng.slug})",
        cwd: plat,
        env: [],
    })
    $cmds = $cmds.append(bund)
    bund_id = $id
    $id = $id + 1

    move = Build.cmd({
        id: $id,
        depends_on: [bund_id],
        inputs: [],
        outputs: [],
        program: "sh",
        args: [
            "-c",
            "mkdir -p bundle-out/${eng.slug} && mv -f platform-out/${eng.slug}/*.tar.zst bundle-out/${eng.slug}/",
        ],
        description: "move bundle tar.zst (${eng.slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(move)
    move_id = $id
    $id = $id + 1

    { cmds: $cmds, terminal_ids: [move_id], next_id: $id }
}

## Stage labeled assets + NOTES.md, then gh release create.
## Asset name: <slug>-platform-<original-hash>.tar.zst
## Roc only needs the URL body; filename is for humans.
phase_publish : NodeId, List(NodeId), EngineSpec, List(EngineSpec), PublishOpts -> PhaseResult
phase_publish = |start_id, depends_on, baseline, engines, opts| {
    tag_line =
        match opts.tag {
            Tag(t) => Str.concat("TAG='", Str.concat(t, "'\n"))
            AutoTag =>
                Str.join_with(
                    [
                        "SHORT=$(git rev-parse --short=7 HEAD 2>/dev/null || echo nogit)\n",
                        "TAG=\"nightly-$(date -u +%Y-%m-%d)-$SHORT\"\n",
                    ],
                    "",
                )
        }

    # Emit one staging stanza per engine (slug + label baked in at graph-build time)
    var $stage_parts : List(Str) = []
    for e in engines {
        is_base =
            if e.name == baseline.name {
                "yes"
            } else {
                "no"
            }
        $stage_parts =
            List.concat(
                $stage_parts,
                [
                    "stage_engine '",
                    e.slug,
                    "' '",
                    engine_label(e),
                    "' '",
                    is_base,
                    "'\n",
                ],
            )
    }
    stage_loop = Str.join_with($stage_parts, "")

    script =
        Str.join_with(
            [
                "set -eu\n",
                "if [ -z \"",
                sh_dollar_brace("GITHUB_TOKEN:-"),
                "\" ]; then\n",
                "  echo \"[publish] GITHUB_TOKEN required\" >&2\n",
                "  exit 1\n",
                "fi\n",
                "if ! command -v gh >/dev/null 2>&1; then\n",
                "  echo \"[publish] gh CLI not found\" >&2\n",
                "  exit 1\n",
                "fi\n",
                "REPO=\"",
                sh_dollar_brace("GITHUB_REPOSITORY:-"),
                "\"\n",
                "if [ -z \"$REPO\" ]; then\n",
                "  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)\n",
                "fi\n",
                "if [ -z \"$REPO\" ]; then\n",
                "  echo \"[publish] GITHUB_REPOSITORY unset and gh repo view failed\" >&2\n",
                "  exit 1\n",
                "fi\n",
                tag_line,
                "SHA=$(git rev-parse --short=7 HEAD 2>/dev/null || echo nogit)\n",
                "STAGING=release-assets\n",
                "rm -rf \"$STAGING\"\n",
                "mkdir -p \"$STAGING\"\n",
                "NOTES=\"$STAGING/NOTES.md\"\n",
                "ASSETS=()\n",
                "URLS=()          # parallel to ASSETS: download URL\n",
                "LABELS=()        # parallel: human label\n",
                "SLUGS=()         # parallel: engine slug\n",
                "IS_BASE=()       # parallel: yes|no\n",
                "\n",
                "stage_engine() {\n",
                "  _slug=\"$1\"\n",
                "  _label=\"$2\"\n",
                "  _base=\"$3\"\n",
                "  _dir=\"bundle-out/$_slug\"\n",
                "  if [ ! -d \"$_dir\" ]; then\n",
                "    echo \"[publish] missing $_dir\" >&2\n",
                "    return 0\n",
                "  fi\n",
                "  # shellcheck disable=SC2206\n",
                "  _files=(\"$_dir\"/*.tar.zst)\n",
                "  if [ ! -e \"",
                sh_dollar_brace("_files[0]"),
                "\" ]; then\n",
                "    echo \"[publish] no .tar.zst under $_dir\" >&2\n",
                "    return 0\n",
                "  fi\n",
                "  _src=\"",
                sh_dollar_brace("_files[0]"),
                "\"\n",
                "  _hash=$(basename \"$_src\" .tar.zst)\n",
                "  _dest=\"$STAGING/${_slug}-platform-${_hash}.tar.zst\"\n",
                "  cp -f \"$_src\" \"$_dest\"\n",
                "  ASSETS+=(\"$_dest\")\n",
                "  URLS+=(\"https://github.com/${REPO}/releases/download/${TAG}/$(basename \"$_dest\")\")\n",
                "  LABELS+=(\"$_label\")\n",
                "  SLUGS+=(\"$_slug\")\n",
                "  IS_BASE+=(\"$_base\")\n",
                "  echo \"[publish] staged $(basename \"$_dest\")\"\n",
                "}\n",
                "\n",
                stage_loop,
                "\n",
                "if [ ",
                sh_dollar_brace("#ASSETS[@]"),
                " -eq 0 ]; then\n",
                "  echo \"[publish] no assets to upload\" >&2\n",
                "  exit 1\n",
                "fi\n",
                "\n",
                "# ---- NOTES.md ----\n",
                "{\n",
                "  echo \"## godot-roc ${TAG}\"\n",
                "  echo\n",
                "  echo \"Commit: \\`${SHA}\\`\"\n",
                "  echo\n",
                "  echo \"### Assets\"\n",
                "  echo\n",
                "  i=0\n",
                "  while [ \"$i\" -lt ",
                sh_dollar_brace("#ASSETS[@]"),
                " ]; do\n",
                "    echo \"- **",
                sh_dollar_brace("LABELS[$i]"),
                "** (\\`",
                sh_dollar_brace("SLUGS[$i]"),
                "\\`)\"\n",
                "    echo \"  - file: \\`$(basename \"",
                sh_dollar_brace("ASSETS[$i]"),
                "\")\\`\"\n",
                "    echo \"  - url: \\`",
                sh_dollar_brace("URLS[$i]"),
                "\\`\"\n",
                "    echo\n",
                "    i=$((i + 1))\n",
                "  done\n",
                "  echo \"### Getting started\"\n",
                "  echo\n",
                "  echo \"Pick **one** platform URL below (uncomment / swap as needed).\"\n",
                "  echo\n",
                "  i=0\n",
                "  while [ \"$i\" -lt ",
                sh_dollar_brace("#ASSETS[@]"),
                " ]; do\n",
                "    _lab=\"",
                sh_dollar_brace("LABELS[$i]"),
                "\"\n",
                "    _url=\"",
                sh_dollar_brace("URLS[$i]"),
                "\"\n",
                "    _base=\"",
                sh_dollar_brace("IS_BASE[$i]"),
                "\"\n",
                "    echo \"#### ${_lab}\"\n",
                "    echo\n",
                "    echo '```roc'\n",
                "    echo 'app [ready!, process!, scene_init!, physics_process!] {'\n",
                "    if [ \"$_base\" = \"yes\" ]; then\n",
                "      echo \"    # [baseline] ${_lab}\"\n",
                "      echo \"    pf: platform \\\"${_url}\\\",\"\n",
                "    else\n",
                "      echo \"    # ${_lab}\"\n",
                "      echo \"    # pf: platform \\\"${_url}\\\",\"\n",
                "    fi\n",
                "    echo '}'\n",
                "    echo\n",
                "    echo 'scene_init! : () => {}'\n",
                "    echo 'scene_init! = || {'\n",
                "    echo '    # ...'\n",
                "    echo '    {}'\n",
                "    echo '}'\n",
                "    echo\n",
                "    echo 'ready! : () => {}'\n",
                "    echo 'ready! = || {'\n",
                "    echo '    # ...'\n",
                "    echo '    {}'\n",
                "    echo '}'\n",
                "    echo\n",
                "    echo 'process! : GodotRoc.ClassId, F64 => {}'\n",
                "    echo 'process! = |_class_id, _delta| {'\n",
                "    echo '    # ...'\n",
                "    echo '    {}'\n",
                "    echo '}'\n",
                "    echo\n",
                "    echo 'physics_process! : GodotRoc.ClassId, F64 => {}'\n",
                "    echo 'physics_process! = |class_id, delta| {'\n",
                "    echo '    # ...'\n",
                "    echo '    {}'\n",
                "    echo '}'\n",
                "    echo '```'\n",
                "    echo\n",
                "    i=$((i + 1))\n",
                "  done\n",
                "  echo \"### All platforms in one app header (pick one)\"\n",
                "  echo\n",
                "  echo '```roc'\n",
                "  echo 'app [ready!, process!, scene_init!, physics_process!] {'\n",
                "  i=0\n",
                "  while [ \"$i\" -lt ",
                sh_dollar_brace("#ASSETS[@]"),
                " ]; do\n",
                "    _lab=\"",
                sh_dollar_brace("LABELS[$i]"),
                "\"\n",
                "    _url=\"",
                sh_dollar_brace("URLS[$i]"),
                "\"\n",
                "    _base=\"",
                sh_dollar_brace("IS_BASE[$i]"),
                "\"\n",
                "    if [ \"$_base\" = \"yes\" ]; then\n",
                "      echo \"    # [baseline] ${_lab}\"\n",
                "      echo \"    pf: platform \\\"${_url}\\\",\"\n",
                "    else\n",
                "      echo \"    # ${_lab}\"\n",
                "      echo \"    # pf: platform \\\"${_url}\\\",\"\n",
                "    fi\n",
                "    i=$((i + 1))\n",
                "  done\n",
                "  echo '}'\n",
                "  echo '```'\n",
                "} >\"$NOTES\"\n",
                "\n",
                "echo \"[publish] release $TAG (",
                sh_dollar_brace("#ASSETS[@]"),
                " assets)\"\n",
                "gh release create \"$TAG\" ",
                sh_dollar_brace("ASSETS[@]"),
                " \\\n",
                "  --title \"godot-roc $TAG\" \\\n",
                "  --notes-file \"$NOTES\"\n",
            ],
            "",
        )

    cmd = Build.cmd({
        id: start_id,
        depends_on,
        inputs: [],
        outputs: [],
        program: "sh",
        args: ["-c", script],
        description: "GitHub release (labeled assets + notes)",
        cwd: "",
        env: [],
    })

    {
        cmds: [cmd],
        terminal_ids: [start_id],
        next_id: start_id + 1,
    }
}

# =============================================================================
# main!
# =============================================================================

main! : List(Str) => Try({}, [Exit(I32)])
main! = |args| {
    cfg = parse_config(args)

    Log.info!("Publish — engine × host matrix (Zig hosts sequential)")
    Log.info!("optimize=${optimize_str(cfg.optimize)}")
    Log.info!("baseline=${cfg.baseline.slug}")
    Log.info!("engines:")
    for e in cfg.engines {
        Log.info!("  - ${e.slug} (cli=${e.cli_id})")
    }
    Log.info!("hosts:")
    for h in cfg.hosts {
        Log.info!("  - ${h.name_str}")
    }

    prep = phase_prepare(1, cfg.engines)
    var $id = prep.next_id
    var $cmds = prep.cmds
    var $bundle_terms = []
    var $zig_prior : List(NodeId) = []

    for e in cfg.engines {
        Log.info!("engine=${e.slug}")

        d = phase_dump($id, prep.terminal_ids, e)
        $cmds = List.concat($cmds, d.cmds)
        $id = d.next_id

        g = phase_glue_engine($id, prep.terminal_ids, d.terminal_ids, e, cfg.hosts)
        $cmds = List.concat($cmds, g.cmds)
        $id = g.next_id

        h = phase_hosts_engine($id, g.terminal_ids, $zig_prior, e, cfg.hosts, cfg.optimize)
        $cmds = List.concat($cmds, h.cmds)
        $id = h.next_id
        $zig_prior = h.terminal_ids

        b = phase_bundle_engine($id, h.terminal_ids, e, cfg.hosts)
        $cmds = List.concat($cmds, b.cmds)
        $id = b.next_id
        $bundle_terms = List.concat($bundle_terms, b.terminal_ids)
    }

    pub = phase_publish($id, $bundle_terms, cfg.baseline, cfg.engines, cfg.publish)
    $cmds = List.concat($cmds, pub.cmds)

    Log.info!("total cmds=${$cmds.len().to_str()}")

    graph = Build.graph($cmds)
    match Build.run!(graph) {
        Ok({}) => {
            Log.info!("publish finished")
            for eng in cfg.engines {
                Log.info!("  bundle-out/${eng.slug}/")
            }
            Ok({})
        }
        Err(BuildFailed(msg)) => {
            Log.error!(msg)
            Err(Exit(1))
        }
    }
}
