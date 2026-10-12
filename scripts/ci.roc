#!/usr/bin/env roc

#
# CI smoke: redot × x64musl only
#
#   roc run scripts/ci.roc
#   nix run github:lukewilliamboswell/roc-blueprint/0.5.0 -- run ci
#

app [main!] {
    pf: platform "https://github.com/scottc/roc-build/releases/download/v0.0.5-alpha/5YqLuJixx2M3z6GcQN666sSVW2TXZkDt52Ny7V67poSD.tar.zst",
}

import pf.Build
import pf.Log

# =============================================================================
# Fixed smoke matrix (no CLI matrix)
# =============================================================================

NodeId : U64

PhaseResult : {
    cmds : List(Build.Cmd),
    terminal_ids : List(NodeId),
    next_id : NodeId,
}

ReplacePair : { find : Str, replace : Str }

# Engine: redot (what is on PATH in the ci Blueprint env)
engine_slug : Str
engine_slug = "redot"

engine_program : Str
engine_program = "redot"

# Host: x64musl only
host_name : Str
host_name = "x64musl"

host_zig_triple : Str
host_zig_triple = "x86_64-linux-musl"

host_lib_file : Str
host_lib_file = "libhost.a"

optimize : Str
optimize = "Debug"

dump_out : Str
dump_out = "dump-out/${engine_slug}"

platform_out : Str
platform_out = "platform-out/${engine_slug}"

glue_out : Str
glue_out = "host/glue-out/${engine_slug}"

smoke_proj : Str
smoke_proj = "smoke-out/${engine_slug}/workspace/my_game"

glue_spec : Str
glue_spec = "vendor/roc/nightly-2026-09-27-a3ce7f1/ZigGlue.roc"

# =============================================================================
# Shell helpers
# =============================================================================

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

phase_prepare : NodeId -> PhaseResult
phase_prepare = |start_id| {
    var $id = start_id
    var $cmds = []
    var $clean_ids = []

    roots = [
        "dump-out",
        "platform-out",
        "host/glue-out",
        "smoke-out",
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
        $clean_ids = $clean_ids.append($id)
        $id = $id + 1
    }

    dirs = [
        dump_out,
        platform_out,
        "${platform_out}/targets",
        "${platform_out}/targets/${host_name}",
        glue_out,
        "smoke-out/${engine_slug}",
        "smoke-out/${engine_slug}/workspace",
        smoke_proj,
    ]
    var $terminals = []
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

    { cmds: $cmds, terminal_ids: $terminals, next_id: $id }
}

phase_dump : NodeId, List(NodeId) -> PhaseResult
phase_dump = |start_id, prepare_ids| {
    dump = Build.cmd({
        id: start_id,
        depends_on: prepare_ids,
        inputs: [],
        outputs: [
            "${dump_out}/gdextension_interface.h",
            "${dump_out}/extension_api.json",
        ],
        program: engine_program,
        args: ["--headless", "--dump-gdextension-interface", "--dump-extension-api"],
        description: "dump gdextension + extension_api (${engine_slug})",
        cwd: dump_out,
        env: [],
    })
    { cmds: [dump], terminal_ids: [start_id], next_id: start_id + 1 }
}

phase_glue : NodeId, List(NodeId), List(NodeId) -> PhaseResult
phase_glue = |start_id, prepare_ids, dump_ids| {
    var $id = start_id
    var $cmds = []
    deps = List.concat(prepare_ids, dump_ids)

    gen_iface = Build.cmd({
        id: $id,
        depends_on: deps,
        inputs: ["${dump_out}/gdextension_interface.h"],
        outputs: ["${glue_out}/gdextension_interface.zig"],
        program: "roc",
        args: [
            "run",
            "scripts/gdextension_interface.generate.roc",
            "--",
            "--engine=${engine_slug}",
        ],
        description: "Generate gdextension_interface (${engine_slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(gen_iface)
    gen_iface_id = $id
    $id = $id + 1

    gen_api = Build.cmd({
        id: $id,
        depends_on: deps,
        inputs: ["${dump_out}/extension_api.json"],
        outputs: [
            "${platform_out}/main.roc",
            "${glue_out}/zig_platform_abi_impl.zig",
        ],
        program: "roc",
        args: [
            "run",
            "scripts/extension_api.generate.roc",
            "--",
            "--engine=${engine_slug}",
            "--targets=${host_name}",
        ],
        description: "Generate extension_api platform (${engine_slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(gen_api)
    gen_api_id = $id
    $id = $id + 1

    glue = Build.cmd({
        id: $id,
        depends_on: [gen_api_id],
        inputs: [glue_spec, "${platform_out}/main.roc"],
        outputs: ["${glue_out}/roc_platform_abi.zig"],
        program: "roc",
        args: [
            "glue",
            glue_spec,
            glue_out,
            "${platform_out}/main.roc",
        ],
        description: "roc glue (${engine_slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(glue)
    glue_id = $id
    $id = $id + 1

    patch = find_replace_cmd(
        $id,
        [glue_id],
        "${glue_out}/roc_platform_abi.zig",
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
        "patch glue marker (${engine_slug})",
    )
    $cmds = $cmds.append(patch)
    patch_id = $id
    $id = $id + 1

    abi_note = Build.cmd({
        id: $id,
        depends_on: [patch_id],
        inputs: ["${glue_out}/roc_platform_abi.zig"],
        outputs: ["${glue_out}/roc_platform_abi.zig"],
        program: "sh",
        args: [
            "-c",
            Str.join_with(
                [
                    "set -eu\n",
                    "F='",
                    glue_out,
                    "/roc_platform_abi.zig'\n",
                    "if [ ! -f \"$F\" ]; then echo missing \"$F\" >&2; exit 1; fi\n",
                    "grep -q 'PATCHED BY scripts/ci.roc' \"$F\" || printf '\\n// PATCHED BY scripts/ci.roc (glue)\\n' >> \"$F\"\n",
                ],
                "",
            ),
        ],
        description: "note patched glue (${engine_slug})",
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
        outputs: ["${glue_out}/gde_call.zig"],
        program: "cp",
        args: ["host/gde_call.template.zig", "${glue_out}/gde_call.zig"],
        description: "cp gde_call.zig (${engine_slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(cp_gde)
    cp_id = $id
    $id = $id + 1

    zt = Build.cmd({
        id: $id,
        depends_on: [gen_iface_id],
        inputs: ["${glue_out}/gdextension_interface.zig"],
        outputs: [],
        program: "zig",
        args: ["test", "${glue_out}/gdextension_interface.zig"],
        description: "zig test gdextension_interface (${engine_slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(zt)
    zt_id = $id
    $id = $id + 1

    rc = Build.cmd({
        id: $id,
        depends_on: [gen_api_id],
        inputs: ["${platform_out}/main.roc"],
        outputs: [],
        program: "roc",
        args: ["check", "${platform_out}/main.roc"],
        description: "roc check platform (${engine_slug})",
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

phase_host : NodeId, List(NodeId) -> PhaseResult
phase_host = |start_id, glue_ids| {
    out_dir = "${platform_out}/targets/${host_name}"
    out_path = "${out_dir}/${host_lib_file}"

    mk = Build.cmd({
        id: start_id,
        depends_on: glue_ids,
        inputs: [],
        outputs: [],
        program: "mkdir",
        args: ["-p", out_dir],
        description: "mkdir host target ${engine_slug}/${host_name}",
        cwd: "",
        env: [],
    })

    compile = Build.cmd({
        id: start_id + 1,
        depends_on: [start_id],
        inputs: ["host/host.zig"],
        outputs: [out_path],
        program: "zig",
        args: [
            "build-lib",
            "host/host.zig",
            "-target",
            host_zig_triple,
            "-O${optimize}",
            "-fPIC",
            "-lc",
            "-fcompiler-rt",
            "--name",
            "host",
            "-static",
            "-femit-bin=${out_path}",
        ],
        description: "compile host ${engine_slug}/${host_name}",
        cwd: "",
        env: [],
    })

    {
        cmds: [mk, compile],
        terminal_ids: [start_id + 1],
        next_id: start_id + 2,
    }
}

phase_workspace : NodeId, List(NodeId) -> PhaseResult
phase_workspace = |start_id, host_ids| {
    var $id = start_id
    var $cmds = []

    mk = Build.cmd({
        id: $id,
        depends_on: host_ids,
        inputs: [],
        outputs: [],
        program: "mkdir",
        args: ["-p", smoke_proj],
        description: "mkdir smoke project (${engine_slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(mk)
    mk_id = $id
    $id = $id + 1

    cp_tpl = Build.cmd({
        id: $id,
        depends_on: [mk_id],
        inputs: ["templates/ci/main.roc"],
        outputs: ["${smoke_proj}/main.roc"],
        program: "cp",
        args: ["-a", "templates/ci/.", "${smoke_proj}/"],
        description: "cp template game (${engine_slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(cp_tpl)
    tpl_id = $id
    $id = $id + 1

    cp_plat = Build.cmd({
        id: $id,
        depends_on: [tpl_id],
        inputs: ["${platform_out}/main.roc"],
        outputs: ["${smoke_proj}/platform/main.roc"],
        program: "cp",
        args: ["-a", "${platform_out}/.", "${smoke_proj}/platform/"],
        description: "cp local platform into smoke (${engine_slug})",
        cwd: "",
        env: [],
    })
    $cmds = $cmds.append(cp_plat)
    plat_id = $id
    $id = $id + 1

    patch = find_replace_cmd(
        $id,
        [plat_id],
        "${smoke_proj}/main.roc",
        [
            {
                find: "pf: platform \"[PLATFORM_GOES_HERE]\",",
                replace: "pf: platform \"./platform/main.roc\",",
            },
        ],
        "patch platform path (${engine_slug})",
    )
    $cmds = $cmds.append(patch)
    patch_id = $id
    $id = $id + 1

    { cmds: $cmds, terminal_ids: [patch_id], next_id: $id }
}

phase_smoke : NodeId, List(NodeId) -> PhaseResult
phase_smoke = |start_id, ws_ids| {
    main_roc = "${smoke_proj}/main.roc"
    out_so = "${smoke_proj}/my_game.so"

    desk = Build.cmd({
        id: start_id,
        depends_on: ws_ids,
        inputs: [main_roc],
        outputs: [out_so],
        program: "roc",
        args: [
            "build",
            main_roc,
            "--target=${host_name}",
            "--no-cache",
            "--output=${out_so}",
        ],
        description: "roc build desktop smoke (${engine_slug}/${host_name})",
        cwd: "",
        env: [],
    })

    { cmds: [desk], terminal_ids: [start_id], next_id: start_id + 1 }
}

# =============================================================================
# main!
# =============================================================================

main! : List(Str) => Try({}, [Exit(I32)])
main! = |_args| {
    Log.info!("CI smoke — ${engine_slug} × ${host_name} (-O${optimize})")

    prep = phase_prepare(1)
    d = phase_dump(prep.next_id, prep.terminal_ids)
    g = phase_glue(d.next_id, prep.terminal_ids, d.terminal_ids)
    h = phase_host(g.next_id, g.terminal_ids)
    w = phase_workspace(h.next_id, h.terminal_ids)
    s = phase_smoke(w.next_id, w.terminal_ids)

    cmds =
        List.concat(
            prep.cmds,
            List.concat(
                d.cmds,
                List.concat(
                    g.cmds,
                    List.concat(h.cmds, List.concat(w.cmds, s.cmds)),
                ),
            ),
        )

    Log.info!("total cmds=${cmds.len().to_str()}")

    graph = Build.graph(cmds)
    match Build.run!(graph) {
        Ok({}) => {
            Log.info!("smoke ok")
            Log.info!("  platform: ${platform_out}")
            Log.info!("  app:      ${smoke_proj}")
            Log.info!("  so:       ${smoke_proj}/my_game.so")
            Ok({})
        }
        Err(BuildFailed(msg)) => {
            Log.error!(msg)
            Err(Exit(1))
        }
    }
}
