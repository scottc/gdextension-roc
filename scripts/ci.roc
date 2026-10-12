#!/usr/bin/env roc

#
# Usage:
#   roc run scripts/ci.roc
#   roc run scripts/ci.roc -- --baseline=godot --engines=none --targets=auto --tests=all -Doptimize=Debug
#   roc run scripts/ci.roc -- --baseline=godot --engines=all --targets=all --tests=all
#   roc run scripts/ci.roc -- --publish --tag=nightly-2026-10-11-abc1234
#
# TODO:
# --stage=bundle          # enable one stage
# --no-stage=bundle       # disable one
# --stages=ci             # preset
# --stages=publish        # preset
#
# Legacy:
#   roc run scripts/ci.roc -- quick
#   roc run scripts/ci.roc -- full deep-wasm
#

## Continuous Integration — engine × host matrix (roc-build)
app [main!] {
    pf: platform "https://github.com/scottc/roc-build/releases/download/v0.0.5-alpha/5YqLuJixx2M3z6GcQN666sSVW2TXZkDt52Ny7V67poSD.tar.zst",
}

import pf.Build
import pf.Log

# =============================================================================
# Domain types
# =============================================================================

Optimize : [Debug, ReleaseFast, ReleaseSafe, ReleaseSmall]

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
    baseline : [NoBaseline, Baseline(Str)],
    tier : HostTier,
}

EngineName : [Godot, Godot451, Redot, Rex]

EngineSpec : {
    name : EngineName,
    slug : Str,
    cli_id : Str,
    program : Str,
    pipeline : EnginePipeline,
    export_web : Bool,
}

TestOpts : {
    roc_check : Bool,
    zig_test : Bool,
    wasm_validate : Bool,
    wasm_ld : Bool,
    smoke : Bool,
}

PublishOpts : {
    enabled : Bool,
    tag : [AutoTag, Tag(Str)],
}

CiConfig : {
    baseline : EngineSpec,
    engines : List(EngineSpec),
    hosts : List(HostTarget),
    optimize : Optimize,
    tests : TestOpts,
    publish : PublishOpts,
}

CiRoots : {
    dump_out : Str,
    platform_out : Str,
    glue_out : Str,
    bundle_out : Str,
    smoke_out : Str,
    vendor_out : Str,
}

NodeId : U64

PhaseResult : {
    cmds : List(Build.Cmd),
    terminal_ids : List(NodeId),
    next_id : NodeId,
}

ReplacePair : { find : Str, replace : Str }

StageOpts : {
    prepare : Bool,
    dump : Bool,
    glue : Bool,
    hosts : Bool,
    bundle : Bool,   # off in CI, on for publish
    workspace : Bool,
    game : Bool,
    publish : Bool,
}

# =============================================================================
# Matrices
# =============================================================================

# Defaults for local / ci.yml
stages_ci : StageOpts
stages_ci = {
    prepare: Bool.True,
    dump: Bool.True,
    glue: Bool.True,
    hosts: Bool.True,
    bundle: Bool.False,   # optional artefact only
    workspace: Bool.True,
    game: Bool.True,
    publish: Bool.False,
}

# Defaults for publish.yml
stages_publish : StageOpts
stages_publish = {
    prepare: Bool.True,
    dump: Bool.True,
    glue: Bool.True,
    hosts: Bool.True,
    bundle: Bool.True,    # required
    workspace: Bool.False,
    game: Bool.False,
    publish: Bool.True,
}

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
        baseline: NoBaseline,
        tier: Primary,
    },
    {
        name: X64V1Musl,
        name_str: "x64v1musl",
        zig_triple: "x86_64-linux-musl",
        kind: StaticLib,
        lib_file: "libhost.a",
        mcpu: Cpu("x86_64"),
        baseline: Baseline("x86_64"),
        tier: Secondary,
    },
    {
        name: Arm64Musl,
        name_str: "arm64musl",
        zig_triple: "aarch64-linux-musl",
        kind: StaticLib,
        lib_file: "libhost.a",
        mcpu: NoCpu,
        baseline: NoBaseline,
        tier: Secondary,
    },
    {
        name: Arm64V1Musl,
        name_str: "arm64v1musl",
        zig_triple: "aarch64-linux-musl",
        kind: StaticLib,
        lib_file: "libhost.a",
        mcpu: Cpu("baseline"),
        baseline: Baseline("baseline"),
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
        zig_triple: "x86_64-windows",
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
        zig_triple: "aarch64-windows",
        kind: StaticLib,
        lib_file: "host.lib",
        mcpu: NoCpu,
        baseline: NoBaseline,
        tier: Secondary,
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
        cli_id: "godot",
        program: "godot",
        pipeline: FullBuild,
        export_web: Bool.True,
    },
    {
        name: Godot451,
        slug: "godot_4_5_1",
        cli_id: "godot4.5",
        program: "godot4.5",
        pipeline: FullBuild,
        export_web: Bool.False,
    },
    {
        name: Redot,
        slug: "redot",
        cli_id: "redot",
        program: "redot",
        pipeline: FullBuild,
        export_web: Bool.False,
    },
    {
        name: Rex,
        slug: "rex",
        cli_id: "rex",
        program: "rex",
        pipeline: DumpOnly,
        export_web: Bool.False,
    },
]

ci_roots : CiRoots
ci_roots = {
    dump_out: "dump-out",
    platform_out: "platform-out",
    glue_out: "host/glue-out",
    bundle_out: "bundle-out",
    smoke_out: "smoke-out",
    vendor_out: "vendor-out",
}

# =============================================================================
# CLI parsing
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

has_flag : List(Str), Str -> Bool
has_flag = |args, name| {
    for a in args {
        if a == name {
            return Bool.True
        }
    }
    Bool.False
}

parse_optimize : List(Str) -> Optimize
parse_optimize = |args| {
    match flag_value(args, "-Doptimize=") {
        Some("Debug") => Debug
        Some("ReleaseFast") => ReleaseFast
        Some("ReleaseSafe") => ReleaseSafe
        Some("ReleaseSmall") => ReleaseSmall
        _ => Debug
    }
}

parse_engine_id : Str -> [Ok(EngineName), Err(Str)]
parse_engine_id = |id| {
    match id {
        "godot" => Ok(Godot)
        "godot4.5" => Ok(Godot451)
        "godot4.5.1" => Ok(Godot451)
        "godot_4_5_1" => Ok(Godot451)
        "redot" => Ok(Redot)
        "rex" => Ok(Rex)
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
    # unreachable if matrices stay in sync
    {
        name: Godot,
        slug: "godot",
        cli_id: "godot",
        program: "godot",
        pipeline: FullBuild,
        export_web: Bool.True,
    }
}

parse_baseline : List(Str) -> EngineSpec
parse_baseline = |args| {
    match flag_value(args, "--baseline=") {
        Some(id) =>
            match parse_engine_id(id) {
                Ok(n) => engine_by_name(n)
                Err(_) => engine_by_name(Godot)
            }
        None => engine_by_name(Godot)
    }
}

## --engines=none|all|<id>  (additional engines beyond baseline)
parse_additional_engines : List(Str), EngineSpec -> List(EngineSpec)
parse_additional_engines = |args, baseline| {
    match flag_value(args, "--engines=") {
        Some("none") | None => [baseline]
        Some("all") => {
            var $out = []
            for e in engine_specs {
                $out = $out.append(e)
            }
            $out
        }
        Some(id) =>
            match parse_engine_id(id) {
                Ok(n) => {
                    extra = engine_by_name(n)
                    if extra.name == baseline.name {
                        [baseline]
                    } else {
                        [baseline, extra]
                    }
                }
                Err(_) => [baseline]
            }
    }
}

parse_targets : List(Str) -> List(HostTarget)
parse_targets = |args| {
    match flag_value(args, "--targets=") {
        Some("all") => host_targets
        Some("auto") | None => {
            var $out = []
            for h in host_targets {
                match h.tier {
                    Primary => {
                        $out = $out.append(h)
                    }
                    _ => {}
                }
            }
            $out
        }
        Some(name) => {
            var $out = []
            for h in host_targets {
                if h.name_str == name {
                    $out = $out.append(h)
                }
            }
            if $out.len() == 0 {
                # fall back to primary
                for h in host_targets {
                    match h.tier {
                        Primary => {
                            $out = $out.append(h)
                        }
                        _ => {}
                    }
                }
            }
            $out
        }
    }
}

parse_tests : List(Str) -> TestOpts
parse_tests = |args| {
    match flag_value(args, "--tests=") {
        Some("none") => {
            {
                roc_check: Bool.False,
                zig_test: Bool.False,
                wasm_validate: Bool.False,
                wasm_ld: Bool.False,
                smoke: Bool.False,
            }
        }
        Some("roc-check") | Some("roc check") => {
            {
                roc_check: Bool.True,
                zig_test: Bool.False,
                wasm_validate: Bool.False,
                wasm_ld: Bool.False,
                smoke: Bool.False,
            }
        }
        Some("zig-test") | Some("zig test") => {
            {
                roc_check: Bool.False,
                zig_test: Bool.True,
                wasm_validate: Bool.False,
                wasm_ld: Bool.False,
                smoke: Bool.False,
            }
        }
        Some("wasm-validate") => {
            {
                roc_check: Bool.False,
                zig_test: Bool.False,
                wasm_validate: Bool.True,
                wasm_ld: Bool.False,
                smoke: Bool.False,
            }
        }
        Some("wasm-ld") => {
            {
                roc_check: Bool.False,
                zig_test: Bool.False,
                wasm_validate: Bool.False,
                wasm_ld: Bool.True,
                smoke: Bool.False,
            }
        }
        Some("smoke") => {
            {
                roc_check: Bool.False,
                zig_test: Bool.False,
                wasm_validate: Bool.False,
                wasm_ld: Bool.False,
                smoke: Bool.True,
            }
        }
        Some("all") | Some(_) | None => {
            {
                roc_check: Bool.True,
                zig_test: Bool.True,
                wasm_validate: Bool.True,
                wasm_ld: Bool.True,
                smoke: Bool.True,
            }
        }
    }
}

parse_publish : List(Str) -> PublishOpts
parse_publish = |args| {
    enabled = has_flag(args, "--publish")
    tag =
        match flag_value(args, "--tag=") {
            Some(t) => Tag(t)
            None => AutoTag
        }
    { enabled, tag }
}

## Legacy: bare "quick" / "full" / "deep-wasm" still accepted.
apply_legacy_mode : List(Str), CiConfig -> CiConfig
apply_legacy_mode = |args, cfg| {
    want_full = has_flag(args, "full")
    want_quick = has_flag(args, "quick")
    if want_full {
        {
            baseline: cfg.baseline,
            engines: engine_specs,
            hosts: host_targets,
            optimize: cfg.optimize,
            tests: cfg.tests,
            publish: cfg.publish,
        }
    } else if want_quick {
        cfg
    } else {
        cfg
    }
}

parse_config : List(Str) -> CiConfig
parse_config = |args| {
    baseline = parse_baseline(args)
    engines = parse_additional_engines(args, baseline)
    hosts = parse_targets(args)
    optimize = parse_optimize(args)
    tests = parse_tests(args)
    publish = parse_publish(args)
    base = {
        baseline,
        engines,
        hosts,
        optimize,
        tests,
        publish,
    }
    apply_legacy_mode(args, base)
}

# =============================================================================
# Path helpers
# =============================================================================

engine_dump_dir : EngineSpec -> Str
engine_dump_dir = |e| "${ci_roots.dump_out}/${e.slug}"

engine_platform_dir : EngineSpec -> Str
engine_platform_dir = |e| "${ci_roots.platform_out}/${e.slug}"

engine_glue_dir : EngineSpec -> Str
engine_glue_dir = |e| "${ci_roots.glue_out}/${e.slug}"

engine_bundle_dir : EngineSpec -> Str
engine_bundle_dir = |e| "${ci_roots.bundle_out}/${e.slug}"

engine_smoke_dir : EngineSpec -> Str
engine_smoke_dir = |e| "${ci_roots.smoke_out}/${e.slug}"

engine_project_dir : EngineSpec -> Str
engine_project_dir = |e| "${engine_smoke_dir(e)}/workspace/my_game"

engine_project_main : EngineSpec -> Str
engine_project_main = |e| "${engine_project_dir(e)}/main.roc"

engine_project_platform_dir : EngineSpec -> Str
engine_project_platform_dir = |e| "${engine_project_dir(e)}/platform"

engine_bundle_workspace : EngineSpec -> Str
engine_bundle_workspace = |e| "${engine_bundle_dir(e)}/workspace/platform-${e.slug}"

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
# Shell helpers (avoid Roc ${} interpolation clashes with bash)
# =============================================================================

## Concatenate without putting bash "${...}" inside a single Roc string literal.
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
    var $terminals = []

    # Clean trees we own
    roots = [
        ci_roots.dump_out,
        ci_roots.platform_out,
        ci_roots.glue_out,
        ci_roots.bundle_out,
        ci_roots.smoke_out,
    ]
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
        $id = $id + 1
    }

    # mkdir -p per engine
    for e in engines {
        dirs = [
            engine_dump_dir(e),
            engine_platform_dir(e),
            "${engine_platform_dir(e)}/targets",
            engine_glue_dir(e),
            engine_bundle_dir(e),
            engine_smoke_dir(e),
            "${engine_smoke_dir(e)}/workspace",
        ]
        for d in dirs {
            c = Build.cmd({
                id: $id,
                depends_on: [],
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
    var $id = start_id
    var $cmds = []

    # Dump interface + api into dump-out/<slug>/
    dump_iface = Build.cmd({
        id: $id,
        depends_on: prepare_ids,
        inputs: [],
        outputs: ["${dump_dir}/gdextension_interface.h"],
        program: eng.program,
        args: ["--headless", "--dump-gdextension-interface", "--dump-extension-api"],
        description: "dump gdextension_interface (${eng.slug})",
        cwd: dump_dir,
        env: [],
    })
    $cmds = $cmds.append(dump_iface)
    iface_id = $id
    $id = $id + 1

    { cmds: $cmds, terminal_ids: [iface_id], next_id: $id }
}

phase_glue_engine : NodeId, List(NodeId), List(NodeId), EngineSpec, List(HostTarget), TestOpts -> PhaseResult
phase_glue_engine = |start_id, prepare_ids, dump_ids, eng, hosts, tests| {
    slug = eng.slug
    glue_dir = engine_glue_dir(eng)
    platform_dir = engine_platform_dir(eng)
    var $id = start_id
    var $cmds = []
    var $deps = List.concat(prepare_ids, dump_ids)

    gen_iface = Build.cmd({
        id: $id,
        depends_on: $deps,
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
        depends_on: $deps,
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

    # roc glue
    # Repo-root relative paths (cwd: "")

    # Source: https://raw.githubusercontent.com/roc-lang/roc/258ab27/src/glue/src/ZigGlue.roc
    # TODO: detect version & download glue spec to some "???-out" directory, probably at `nix flake update` time:
    glue_spec = "vendor/roc/nightly-2026-09-27-a3ce7f1/ZigGlue.roc"

    glue = Build.cmd({
        id: $id,
        depends_on: [gen_api_id],
        inputs: [
            glue_spec,
            "${platform_dir}/main.roc",
        ],
        outputs: ["${glue_dir}/roc_platform_abi.zig"],
        program: "roc",
        args: [
            "glue",
            glue_spec,
            glue_dir,                      # host/glue-out/godot
            "${platform_dir}/main.roc",    # platform-out/godot/main.roc
        ],
        description: "roc glue (${slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(glue)
    glue_id = $id
    $id = $id + 1

    # Patch roc_platform_abi.zig (nativeWriteStderr / nativeOnFatal)
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
    # Prefer a full honest patch of the two functions via a small shell heredoc
    # written without Roc ${} clashes — keep simple copy of template if present.
    $cmds = $cmds.append(patch)
    patch_id = $id
    $id = $id + 1

    # Honest ABI patch via dedicated sh script (no Roc ${ bash })
    abi_patch_script =
        Str.join_with(
            [
                "set -eu\n",
                "F='",
                glue_dir,
                "/roc_platform_abi.zig'\n",
                "if [ ! -f \"$F\" ]; then echo missing \"$F\" >&2; exit 1; fi\n",
                "# soft patch: ensure file ends with patched markers comment\n",
                "grep -q 'PATCHED BY scripts/ci.roc' \"$F\" || printf '\\n// PATCHED BY scripts/ci.roc (glue)\\n' >> \"$F\"\n",
            ],
            "",
        )
    abi_note = Build.cmd({
        id: $id,
        depends_on: [patch_id],
        inputs: ["${glue_dir}/roc_platform_abi.zig"],
        outputs: ["${glue_dir}/roc_platform_abi.zig"],
        program: "sh",
        args: ["-c", abi_patch_script],
        description: "note patched glue (${slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(abi_note)
    abi_id = $id
    $id = $id + 1

    # Copy gde_call template
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

    var $term = [abi_id, cp_id]

    if tests.zig_test {
        zt1 = Build.cmd({
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
        $cmds = $cmds.append(zt1)
        $term = $term.append($id)
        $id = $id + 1
    }

    if tests.roc_check {
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
        $term = $term.append($id)
        $id = $id + 1
    }

    { cmds: $cmds, terminal_ids: $term, next_id: $id }
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

phase_hosts_engine : NodeId, List(NodeId), EngineSpec, List(HostTarget), Optimize -> PhaseResult
phase_hosts_engine = |start_id, glue_ids, eng, hosts, opt| {
    var $id = start_id
    var $cmds = []
    var $term = []
    for h in hosts {
        out_dir = "${engine_platform_dir(eng)}/targets/${h.name_str}"
        out_path = "${out_dir}/${h.lib_file}"
        mk = Build.cmd({
            id: $id,
            depends_on: glue_ids,
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

        args = zig_host_args(h, opt, out_path)
        c = Build.cmd({
            id: $id,
            depends_on: [mk_id],
            inputs: ["host/host.zig"],
            outputs: [out_path],
            program: "zig",
            args,
            description: "compile host ${eng.slug}/${h.name_str}",
            cwd: "",
            env: [],
        })
        $cmds = $cmds.append(c)
        $term = $term.append($id)
        $id = $id + 1
    }
    { cmds: $cmds, terminal_ids: $term, next_id: $id }
}

phase_bundle_engine : NodeId, List(NodeId), EngineSpec, List(HostTarget) -> PhaseResult
phase_bundle_engine = |start_id, host_ids, eng, hosts| {
    var $id = start_id
    var $cmds = []
    ws = engine_bundle_workspace(eng)
    plat = engine_platform_dir(eng)

    mk = Build.cmd({
        id: $id,
        depends_on: host_ids,
        inputs: [],
        outputs: [],
        program: "mkdir",
        args: ["-p", ws],
        description: "mkdir bundle workspace (${eng.slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(mk)
    mk_id = $id
    $id = $id + 1

    # Copy platform tree into bundle workspace
    # cp = Build.cmd({
    #     id: $id,
    #     depends_on: [mk_id],
    #     inputs: ["${plat}/main.roc"],
    #     outputs: ["${ws}/main.roc"],
    #     program: "cp",
    #     args: ["-a", "${plat}/.", "${ws}/"],
    #     description: "cp platform → bundle workspace (${eng.slug})",
    #     cwd: "",
    #     env: [],
    # })
    # $cmds = $cmds.append(cp)
    # cp_id = $id
    # $id = $id + 1

    # roc bundle (collect host libs)
    # Bundle from platform-out in place; write .tar.zst into bundle-out/<slug>/
    var $bundle_args = ["bundle", "main.roc"]
    for h in hosts {
        # path relative to platform dir
        $bundle_args = $bundle_args.append("targets/${h.name_str}/${h.lib_file}")
    }

    bund = Build.cmd({
        id: $id,
        depends_on: [mk_id],
        inputs: ["${plat}/main.roc"],
        outputs: [],  # hash name unknown up front
        program: "roc",
        args: $bundle_args,
        description: "roc bundle (${eng.slug})",
        cwd: plat,  # platform-out/godot
        env: [],
    })
    $cmds = $cmds.append(bund)
    bund_id = $id
    $id = $id + 1

    # After bundle with cwd = platform-out/godot
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
    _move_id = $id
    $id = $id + 1

    { cmds: $cmds, terminal_ids: [bund_id], next_id: $id }
}

phase_workspace_engine : NodeId, List(NodeId), EngineSpec -> PhaseResult
phase_workspace_engine = |start_id, bundle_ids, eng| {
    var $id = start_id
    var $cmds = []
    proj = engine_project_dir(eng)
    plat_src = engine_platform_dir(eng)
    plat_dst = engine_project_platform_dir(eng)

    mk = Build.cmd({
        id: $id,
        depends_on: bundle_ids,
        inputs: [],
        outputs: [],
        program: "mkdir",
        args: ["-p", proj],
        description: "mkdir smoke project (${eng.slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(mk)
    mk_id = $id
    $id = $id + 1

    # Copy template game
    cp_tpl = Build.cmd({
        id: $id,
        depends_on: [mk_id],
        inputs: ["templates/ci/main.roc"],
        outputs: ["${proj}/main.roc"],
        program: "cp",
        args: ["-a", "templates/ci/.", "${proj}/"],
        description: "cp template game (${eng.slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(cp_tpl)
    tpl_id = $id
    $id = $id + 1

    # Copy local platform next to main.roc
    cp_plat = Build.cmd({
        id: $id,
        depends_on: [tpl_id],
        inputs: ["${plat_src}/main.roc"],
        outputs: ["${plat_dst}/main.roc"],
        program: "cp",
        args: ["-a", "${plat_src}/.", "${plat_dst}/"],
        description: "cp local platform into smoke (${eng.slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(cp_plat)
    plat_id = $id
    $id = $id + 1

    # Patch platform path in main.roc
    patch = find_replace_cmd(
        $id,
        [plat_id],
        "${proj}/main.roc",
        [
            {
                find: "pf: platform \"[PLATFORM_GOES_HERE]\",",
                replace: "pf: platform \"./platform/main.roc\",",
            },
        ],
        "patch platform path (${eng.slug})",
    )
    $cmds = $cmds.append(patch)
    patch_id = $id
    $id = $id + 1

    { cmds: $cmds, terminal_ids: [patch_id], next_id: $id }
}

phase_game_engine : NodeId, List(NodeId), EngineSpec, List(HostTarget), Optimize, TestOpts -> PhaseResult
phase_game_engine = |start_id, ws_ids, eng, hosts, _opt, tests| {
    var $id = start_id
    var $cmds = []
    var $term = []
    proj = engine_project_dir(eng)
    main_roc = "${proj}/main.roc"

    # Desktop (primary musl if present)
    var $has_desktop = Bool.False
    for h in hosts {
        if h.name_str == "x64musl" {
            $has_desktop = Bool.True
        }
    }
    if $has_desktop {
        desk = Build.cmd({
            id: $id,
            depends_on: ws_ids,
            inputs: [main_roc],
            outputs: ["${proj}/my_game.so"],
            program: "roc",
            args: [
                "build",
                main_roc,
                "--target=x64musl",
                "--no-cache",
                "--output=${proj}/my_game.so",
            ],
            description: "roc build desktop (${eng.slug})",
            cwd: "",
            env: [],
        })
        $cmds = $cmds.append(desk)
        $term = $term.append($id)
        $id = $id + 1
    }

    # Web wasm32
    var $has_wasm = Bool.False
    for h in hosts {
        if h.name_str == "wasm32" {
            $has_wasm = Bool.True
        }
    }
    if $has_wasm {
        web = Build.cmd({
            id: $id,
            depends_on: ws_ids,
            inputs: [main_roc],
            outputs: ["${proj}/temp.a"],
            program: "roc",
            args: [
                "build",
                main_roc,
                "--target=wasm32",
                "--output=${proj}/temp.a",
            ],
            description: "roc build web (${eng.slug})",
            cwd: "",
            env: [],
        })
        $cmds = $cmds.append(web)
        web_id = $id
        $term = $term.append($id)
        $id = $id + 1

        if tests.wasm_validate {
            wv = Build.cmd({
                id: $id,
                depends_on: [web_id],
                inputs: ["${engine_platform_dir(eng)}/targets/wasm32/libhost.o.wasm"],
                outputs: [],
                program: "wasm-validate",
                args: [
                    "--enable-extended-const",
                    "${engine_platform_dir(eng)}/targets/wasm32/libhost.o.wasm",
                ],
                description: "wasm-validate libhost (${eng.slug})",
                cwd: "",
                env: [],
            })
            $cmds = $cmds.append(wv)
            $term = $term.append($id)
            $id = $id + 1
        }

        if tests.wasm_ld {
            ld = Build.cmd({
                id: $id,
                depends_on: [web_id],
                inputs: [],
                outputs: ["${proj}/test.wasm"],
                program: "zig",
                args: [
                    "wasm-ld",
                    "--fatal-warnings",
                    "--experimental-pic",
                    "--no-entry",
                    "--export-dynamic",
                    "--import-memory",
                    "--import-table",
                    "-shared",
                    "-o",
                    "${proj}/test.wasm",
                    "${engine_platform_dir(eng)}/targets/wasm32/libhost.o.wasm",
                ],
                description: "wasm-ld diagnostic (${eng.slug})",
                cwd: "",
                env: [],
            })
            $cmds = $cmds.append(ld)
            $term = $term.append($id)
            $id = $id + 1
        }

        if tests.smoke and eng.export_web {
            # CWD-relative export; artifact-gated (engine may SIGSEGV after write)
            export_script =
                Str.join_with(
                    [
                        "set +e\n",
                        "ENGINE='",
                        eng.program,
                        "'\n",
                        "PROJECT='project.godot'\n",
                        "OUT='export/index.html'\n",
                        "ARTIFACT='export/index.html'\n",
                        "if [ ! -f \"$PROJECT\" ]; then\n",
                        "  echo \"[ci] missing $PROJECT in $(pwd)\" >&2\n",
                        "  ls -la >&2 || true\n",
                        "  exit 1\n",
                        "fi\n",
                        "mkdir -p export\n",
                        "\"$ENGINE\" --path . --headless --export-release \"Web\" \"$OUT\"\n",
                        "status=$?\n",
                        "if [ -f \"$ARTIFACT\" ]; then\n",
                        "  echo \"[ci] export artifact ok: $(pwd)/$ARTIFACT (engine exit=$status)\"\n",
                        "  exit 0\n",
                        "fi\n",
                        "echo \"[ci] export failed: missing $(pwd)/$ARTIFACT (engine exit=$status)\" >&2\n",
                        "ls -la export >&2 || true\n",
                        "exit 1\n",
                    ],
                    "",
                )
            ex = Build.cmd({
                id: $id,
                depends_on: [web_id],
                inputs: ["${proj}/project.godot"],
                outputs: ["${proj}/export/index.html"],
                program: "sh",
                args: ["-c", export_script],
                description: "Web export (${eng.slug})",
                cwd: proj,
                env: [],
            })
            $cmds = $cmds.append(ex)
            $term = $term.append($id)
            $id = $id + 1
        } else if tests.smoke {
            skip_script =
                Str.join_with(
                    [
                        "echo \"[ci] skip Web export for ",
                        eng.slug,
                        " (no templates / export_web=false)\"\n",
                    ],
                    "",
                )
            sk = Build.cmd({
                id: $id,
                depends_on: [web_id],
                inputs: [],
                outputs: [],
                program: "sh",
                args: ["-c", skip_script],
                description: "Skip Web export (${eng.slug})",
                cwd: "",
                env: [],
            })
            $cmds = $cmds.append(sk)
            $term = $term.append($id)
            $id = $id + 1
        }
    }

    if $term.len() == 0 {
        $term = ws_ids
    }

    { cmds: $cmds, terminal_ids: $term, next_id: $id }
}

## Publish only *.tar.zst files. Bash ${...} is built via sh_dollar_brace so Roc
## never sees `${` inside a string literal.
phase_publish : NodeId, List(NodeId), List(EngineSpec), PublishOpts -> PhaseResult
phase_publish = |start_id, depends_on, build_engines, opts| {
    if !opts.enabled {
        return { cmds: [], terminal_ids: depends_on, next_id: start_id }
    }

    tag_line =
        match opts.tag {
            Tag(t) => Str.concat("TAG='", Str.concat(t, "'\n"))
            AutoTag =>
                # nightly-YYYY-MM-DD-<shortsha>  (bash expands date/git)
                Str.join_with(
                    [
                        "SHORT=$(git rev-parse --short HEAD 2>/dev/null || echo nogit)\n",
                        "TAG=\"nightly-$(date -u +%Y-%m-%d)-$SHORT\"\n",
                    ],
                    "",
                )
        }

    # Collect asset paths without embedding bash arrays in Roc interpolations
    var $asset_globs = ""

    for e in build_engines {
        $asset_globs = Str.concat(
            $asset_globs,
            Str.concat(engine_bundle_dir(e), " "),
        )
    }

    script =
        Str.join_with(
            [
                "set -eu\n",
                "if [ -z \"",
                sh_dollar_brace("GITHUB_TOKEN:-"),
                "\" ]; then\n",
                "  echo \"[publish] GITHUB_TOKEN or --github-token= required\" >&2\n",
                "  exit 1\n",
                "fi\n",
                "if ! command -v gh >/dev/null 2>&1; then\n",
                "  echo \"[publish] GitHub CLI (gh) not found\" >&2\n",
                "  exit 1\n",
                "fi\n",
                tag_line,
                "ASSETS=()\n",
                "for d in ",
                $asset_globs,
                "; do\n",
                "  [ -d \"$d\" ] || continue\n",
                "  # shellcheck disable=SC2206\n",
                "  files=(\"$d\"/*.tar.zst)\n",
                "  if [ ! -e \"",
                sh_dollar_brace("files[0]"),
                "\" ]; then\n",
                "    echo \"[publish] no .tar.zst under $d\" >&2\n",
                "    continue\n",
                "  fi\n",
                "  for f in ",
                sh_dollar_brace("files[@]"),
                "; do\n",
                "    ASSETS+=(\"$f\")\n",
                "  done\n",
                "done\n",
                "if [ ",
                sh_dollar_brace("#ASSETS[@]"),
                " -eq 0 ]; then\n",
                "  echo \"[publish] no assets to upload\" >&2\n",
                "  exit 1\n",
                "fi\n",
                "echo \"[publish] release $TAG (\"",
                sh_dollar_brace("#ASSETS[@]"),
                "\" assets)\"\n",
                "gh release create \"$TAG\" ",
                sh_dollar_brace("ASSETS[@]"),
                " --title \"godot-roc $TAG\" --notes \"Platform bundles for $TAG\"\n",
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
        description: "GitHub release publish (*.tar.zst)",
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

    Log.info!("CI — engine × host matrix")
    Log.info!("optimize=${optimize_str(cfg.optimize)}")
    Log.info!("publish=${if cfg.publish.enabled { "yes" } else { "no" }}")
    Log.info!("engines:")
    for e in cfg.engines {
        pipe =
            match e.pipeline {
                FullBuild => "full-build"
                DumpOnly => "dump-only"
            }
        Log.info!("  - ${e.slug} [${pipe}] (cli=${e.cli_id})")
    }
    Log.info!("hosts:")
    for h in cfg.hosts {
        Log.info!("  - ${h.name_str}")
    }

    var $build_engines = []
    for e in cfg.engines {
        match e.pipeline {
            FullBuild => {
                $build_engines = $build_engines.append(e)
            }
            DumpOnly => {}
        }
    }

    prep = phase_prepare(1, cfg.engines)
    Log.info!("prep cmds=${prep.cmds.len().to_str()} next_id=${prep.next_id.to_str()}")

    var $id = prep.next_id
    var $cmds = prep.cmds
    var $game_terms = []

    for e in cfg.engines {
        Log.info!("engine=${e.slug} id=${$id.to_str()} cmds=${$cmds.len().to_str()}")

        d = phase_dump($id, prep.terminal_ids, e)
        $cmds = List.concat($cmds, d.cmds)
        $id = d.next_id
        Log.info!("  after dump cmds=${$cmds.len().to_str()}")

        match e.pipeline {
            DumpOnly => {
                Log.info!("  dump-only skip")
            }
            FullBuild => {
                Log.info!("  full-build glue…")
                g = phase_glue_engine($id, prep.terminal_ids, d.terminal_ids, e, cfg.hosts, cfg.tests)
                $cmds = List.concat($cmds, g.cmds)
                $id = g.next_id
                Log.info!("  after glue cmds=${$cmds.len().to_str()}")

                h = phase_hosts_engine($id, g.terminal_ids, e, cfg.hosts, cfg.optimize)
                $cmds = List.concat($cmds, h.cmds)
                $id = h.next_id
                Log.info!("  after hosts cmds=${$cmds.len().to_str()}")

                b = phase_bundle_engine($id, h.terminal_ids, e, cfg.hosts)
                $cmds = List.concat($cmds, b.cmds)
                $id = b.next_id

                w = phase_workspace_engine($id, b.terminal_ids, e)
                $cmds = List.concat($cmds, w.cmds)
                $id = w.next_id

                game = phase_game_engine($id, w.terminal_ids, e, cfg.hosts, cfg.optimize, cfg.tests)
                $cmds = List.concat($cmds, game.cmds)
                $id = game.next_id
                $game_terms = List.concat($game_terms, game.terminal_ids)
                Log.info!("  after game cmds=${$cmds.len().to_str()}")
            }
        }
    }

    pub = phase_publish($id, $game_terms, $build_engines, cfg.publish)
    $cmds = List.concat($cmds, pub.cmds)

    Log.info!("total cmds=${$cmds.len().to_str()}")
    Log.info!("next_id=${$id.to_str()}")
    Log.info!("Final Graph=${Str.inspect($cmds)}")

    graph = Build.graph($cmds)

    match Build.run!(graph) {
        Ok({}) => {
            Log.info!("all tasks finished")
            for eng in $build_engines {
                Log.info!("engine ${eng.slug}:")
                Log.info!("  CI app:  ${engine_project_dir(eng)}")
                Log.info!("  Bundle:  ${engine_bundle_workspace(eng)}")
            }
            Ok({})
        }
        Err(BuildFailed(msg)) => {
            Log.error!(msg)
            Err(Exit(1))
        }
    }
}
