import pf.Build exposing [Cmd, TaskId, BuildGraph]

import modules/Host exposing [Optimize]
import modules/Args exposing [PublishOpts]
import modules/Engine
import modules/CpuArchOS

BuildCmdHelper := {}.{
    PhaseResult : {
        cmds : List(Build.Cmd),
        terminal_ids : List(TaskId),
        next_id : TaskId,
    }

    ReplacePair : { find : Str, replace : Str }

    PubConfig : {
        baseline : Engine,
        engines : List(Engine),
        hosts : List(CpuArchOS),
        optimize : Optimize,
        publish : PublishOpts,
    }


    to_ci_build_graph = || {
        prep = BuildCmdHelper.ci_phase_prepare(1)
        d = BuildCmdHelper.ci_phase_dump(prep.next_id, prep.terminal_ids)
        g = BuildCmdHelper.ci_phase_glue(d.next_id, prep.terminal_ids, d.terminal_ids)
        h = BuildCmdHelper.ci_phase_host(g.next_id, g.terminal_ids)
        w = BuildCmdHelper.ci_phase_workspace(h.next_id, h.terminal_ids)
        s = BuildCmdHelper.ci_phase_smoke(w.next_id, w.terminal_ids)

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

        graph = Build.graph(cmds)

        graph
    }

    # =============================================================================
    # Fixed smoke matrix (no CLI matrix)
    # =============================================================================

    ci_engine : Engine
    ci_engine = Engine.Godot({ major: 4, minor: 3 })
    #ci_engine = Engine.Blazium({ major: 0, minor: 6 })

    ci_cpu_arch_os : CpuArchOS
    ci_cpu_arch_os = CpuArchOS.X64musl

    # TODO: import from modules/Host.roc
    #Optimize : [Debug, ReleaseFast, ReleaseSafe, ReleaseSmall]

    ci_optimize : [Debug, ReleaseFast, ReleaseSafe, ReleaseSmall]
    ci_optimize = Debug

    ci_debug_flag = "-ODebug"

    opt_to_str : [Debug, ReleaseFast, ReleaseSafe, ReleaseSmall] => Str
    opt_to_str = |opt| {
        match opt {
            Debug => "Debug"
            ReleaseFast => "ReleaseFast"
            ReleaseSafe => "ReleaseSafe"
            ReleaseSmall => "ReleaseSmall"
        }
    }

    ci_dump_out : Str
    ci_dump_out = "dump-out/${ci_engine.to_path_slug()}"

    ci_platform_out : Str
    ci_platform_out = "platform-out/${ci_engine.to_path_slug()}"

    ci_glue_out : Str
    ci_glue_out = "host/glue-out/${ci_engine.to_path_slug()}"

    ci_smoke_proj : Str
    ci_smoke_proj = "smoke-out/${ci_engine.to_path_slug()}/workspace/my_game"

    ci_glue_spec : Str
    ci_glue_spec = "vendor/roc/nightly-2026-10-12-2664a27/ZigGlue.roc"

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

    find_replace_cmd : TaskId, List(TaskId), Str, List(ReplacePair), Str -> Build.Cmd
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

    ci_phase_prepare : TaskId -> PhaseResult
    ci_phase_prepare = |start_id| {
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
            ci_dump_out,
            ci_platform_out,
            "${ci_platform_out}/targets",
            "${ci_platform_out}/targets/${ci_cpu_arch_os.to_name()}",
            ci_glue_out,
            "smoke-out/${ci_engine.to_path_slug()}",
            "smoke-out/${ci_engine.to_path_slug()}/workspace",
            ci_smoke_proj,
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

    ci_phase_dump : TaskId, List(TaskId) -> PhaseResult
    ci_phase_dump = |start_id, prepare_ids| {
        dump = Build.cmd({
            id: start_id,
            depends_on: prepare_ids,
            inputs: [],
            outputs: [
                "${ci_dump_out}/gdextension_interface.h",
                "${ci_dump_out}/extension_api.json",
            ],
            program: ci_engine.to_cli_name(),
            args: ["--headless", "--dump-gdextension-interface", "--dump-extension-api"],
            description: "dump gdextension + extension_api (${ci_engine.to_cli_name()} <- ${ci_engine.to_name()})",
            cwd: ci_dump_out,
            env: [],
        })
        { cmds: [dump], terminal_ids: [start_id], next_id: start_id + 1 }
    }

    ci_phase_glue : TaskId, List(TaskId), List(TaskId) -> PhaseResult
    ci_phase_glue = |start_id, prepare_ids, dump_ids| {
        var $id = start_id
        var $cmds = []
        deps = List.concat(prepare_ids, dump_ids)

        gen_iface = Build.cmd({
            id: $id,
            depends_on: deps,
            inputs: ["${ci_dump_out}/gdextension_interface.h"],
            outputs: ["${ci_glue_out}/gdextension_interface.zig"],
            program: "roc",
            args: [
                "run",
                "scripts/gdextension_interface.generate.roc",
                "--",
                "--engine=${ci_engine.to_name()}",
            ],
            description: "Generate gdextension_interface (${ci_engine.to_name()})",
            cwd: "",
            env: [],
        })
        $cmds = $cmds.append(gen_iface)
        gen_iface_id = $id
        $id = $id + 1

        gen_api = Build.cmd({
            id: $id,
            depends_on: deps,
            inputs: ["${ci_dump_out}/extension_api.json"],
            outputs: [
                "${ci_platform_out}/main.roc",
                "${ci_glue_out}/zig_platform_abi_impl.zig",
            ],
            program: "roc",
            args: [
                "run",
                "scripts/extension_api.generate.roc",
                "--",
                "--engine=${ci_engine.to_name()}",
                "--targets=${ci_cpu_arch_os.to_name()}",
            ],
            description: "Generate extension_api platform (${ci_engine.to_name()})",
            cwd: "",
            env: [],
        })
        $cmds = $cmds.append(gen_api)
        gen_api_id = $id
        $id = $id + 1

        glue = Build.cmd({
            id: $id,
            depends_on: [gen_api_id],
            inputs: [ci_glue_spec, "${ci_platform_out}/main.roc"],
            outputs: ["${ci_glue_out}/roc_platform_abi.zig"],
            program: "roc",
            args: [
                "glue",
                ci_glue_spec,
                ci_glue_out,
                "${ci_platform_out}/main.roc",
            ],
            description: "roc glue (${ci_engine.to_name()})",
            cwd: "",
            env: [],
        })
        $cmds = $cmds.append(glue)
        glue_id = $id
        $id = $id + 1

        patch = find_replace_cmd(
            $id,
            [glue_id],
            "${ci_glue_out}/roc_platform_abi.zig",
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
            "patch glue marker (${ci_engine.to_name()})",
        )
        $cmds = $cmds.append(patch)
        patch_id = $id
        $id = $id + 1

        abi_note = Build.cmd({
            id: $id,
            depends_on: [patch_id],
            inputs: ["${ci_glue_out}/roc_platform_abi.zig"],
            outputs: ["${ci_glue_out}/roc_platform_abi.zig"],
            program: "sh",
            args: [
                "-c",
                Str.join_with(
                    [
                        "set -eu\n",
                        "F='",
                        ci_glue_out,
                        "/roc_platform_abi.zig'\n",
                        "if [ ! -f \"$F\" ]; then echo missing \"$F\" >&2; exit 1; fi\n",
                        "grep -q 'PATCHED BY scripts/ci.roc' \"$F\" || printf '\\n// PATCHED BY scripts/ci.roc (glue)\\n' >> \"$F\"\n",
                    ],
                    "",
                ),
            ],
            description: "note patched glue (${ci_engine.to_name()})",
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
            outputs: ["${ci_glue_out}/gde_call.zig"],
            program: "cp",
            args: ["host/gde_call.template.zig", "${ci_glue_out}/gde_call.zig"],
            description: "cp gde_call.zig (${ci_engine.to_name()})",
            cwd: "",
            env: [],
        })
        $cmds = $cmds.append(cp_gde)
        cp_id = $id
        $id = $id + 1

        zt = Build.cmd({
            id: $id,
            depends_on: [gen_iface_id],
            inputs: ["${ci_glue_out}/gdextension_interface.zig"],
            outputs: [],
            program: "zig",
            args: ["test", "${ci_glue_out}/gdextension_interface.zig"],
            description: "zig test gdextension_interface (${ci_engine.to_name()})",
            cwd: "",
            env: [],
        })
        $cmds = $cmds.append(zt)
        zt_id = $id
        $id = $id + 1

        rc = Build.cmd({
            id: $id,
            depends_on: [gen_api_id],
            inputs: ["${ci_platform_out}/main.roc"],
            outputs: [],
            program: "roc",
            args: ["check", "${ci_platform_out}/main.roc"],
            description: "roc check platform (${ci_engine.to_name()})",
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

    ci_phase_host : TaskId, List(TaskId) -> PhaseResult
    ci_phase_host = |start_id, glue_ids| {
        out_dir = "${ci_platform_out}/targets/${ci_cpu_arch_os.to_name()}"
        out_path = "${out_dir}/${Host.to_target(ci_cpu_arch_os).lib_file}"

        mk = Build.cmd({
            id: start_id,
            depends_on: glue_ids,
            inputs: [],
            outputs: [],
            program: "mkdir",
            args: ["-p", out_dir],
            description: "mkdir host target ${ci_engine.to_name()} ${ci_engine.to_path_slug()}/${ci_cpu_arch_os.to_name()}",
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
                Host.to_target(ci_cpu_arch_os).zig_triple,
                ci_debug_flag,
                "-fPIC",
                "-lc",
                "-fcompiler-rt",
                "--name",
                "host",
                "-static",
                "-femit-bin=${out_path}",
            ],
            description: "compile host ${ci_engine.to_name()} ${ci_engine.to_path_slug()}/${ci_cpu_arch_os.to_name()}",
            cwd: "",
            env: [],
        })

        pr : PhaseResult
        pr = {
            cmds: [mk, compile],
            terminal_ids: [start_id + 1],
            next_id: start_id + 2,
        }
        pr
    }

    ci_phase_workspace : TaskId, List(TaskId) -> PhaseResult
    ci_phase_workspace = |start_id, host_ids| {
        var $id = start_id
        var $cmds = []

        mk = Build.cmd({
            id: $id,
            depends_on: host_ids,
            inputs: [],
            outputs: [],
            program: "mkdir",
            args: ["-p", ci_smoke_proj],
            description: "mkdir smoke project (${ci_engine.to_name()})",
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
            outputs: ["${ci_smoke_proj}/main.roc"],
            program: "cp",
            args: ["-a", "templates/ci/.", "${ci_smoke_proj}/"],
            description: "cp template game (${ci_engine.to_name()})",
            cwd: "",
            env: [],
        })
        $cmds = $cmds.append(cp_tpl)
        tpl_id = $id
        $id = $id + 1

        cp_plat = Build.cmd({
            id: $id,
            depends_on: [tpl_id],
            inputs: ["${ci_platform_out}/main.roc"],
            outputs: ["${ci_smoke_proj}/platform/main.roc"],
            program: "cp",
            args: ["-a", "${ci_platform_out}/.", "${ci_smoke_proj}/platform/"],
            description: "cp local platform into smoke (${ci_engine.to_name()})",
            cwd: "",
            env: [],
        })
        $cmds = $cmds.append(cp_plat)
        plat_id = $id
        $id = $id + 1

        patch = find_replace_cmd(
            $id,
            [plat_id],
            "${ci_smoke_proj}/main.roc",
            [
                {
                    find: "pf: platform \"[PLATFORM_GOES_HERE]\",",
                    replace: "pf: platform \"./platform/main.roc\",",
                },
            ],
            "patch platform path (${ci_engine.to_name()})",
        )
        $cmds = $cmds.append(patch)
        patch_id = $id
        $id = $id + 1

        { cmds: $cmds, terminal_ids: [patch_id], next_id: $id }
    }

    ci_phase_smoke : TaskId, List(TaskId) -> PhaseResult
    ci_phase_smoke = |start_id, ws_ids| {
        main_roc = "${ci_smoke_proj}/main.roc"
        out_so = "${ci_smoke_proj}/my_game.so"

        desk = Build.cmd({
            id: start_id,
            depends_on: ws_ids,
            inputs: [main_roc],
            outputs: [out_so],
            program: "roc",
            args: [
                "build",
                main_roc,
                "--target=${ci_cpu_arch_os.to_name()}",
                "--no-cache",
                "--output=${out_so}",
            ],
            description: "roc build desktop smoke ${ci_engine.to_name()} (${ci_engine.to_path_slug()}/${ci_cpu_arch_os.to_name()})",
            cwd: "",
            env: [],
        })

        { cmds: [desk], terminal_ids: [start_id], next_id: start_id + 1 }
    }

    # =============================================================================
    # Paths
    # =============================================================================

    glue_spec : Str
    glue_spec = "vendor/roc/nightly-2026-10-12-2664a27/ZigGlue.roc"

    engine_dump_dir : Engine -> Str
    engine_dump_dir = |e| "dump-out/${e.to_path_slug()}"

    engine_platform_dir : Engine -> Str
    engine_platform_dir = |e| "platform-out/${e.to_path_slug()}"

    engine_glue_dir : Engine -> Str
    engine_glue_dir = |e| "host/glue-out/${e.to_path_slug()}"

    engine_bundle_dir : Engine -> Str
    engine_bundle_dir = |e| "bundle-out/${e.to_path_slug()}"

    #
    # Build Graphs
    #

    to_publish_build_graph : PubConfig -> BuildGraph
    to_publish_build_graph = |cfg| {
        prep = BuildCmdHelper.phase_prepare(1, cfg.baseline, cfg.engines)
        var $id = prep.next_id
        var $cmds = prep.cmds
        var $bundle_terms = []
        $zig_prior : List(TaskId)
        var $zig_prior = []

        bld = BuildCmdHelper.phase_dump($id, prep.terminal_ids, cfg.baseline)
        $cmds = List.concat($cmds, bld.cmds)
        $id = bld.next_id

        blg = BuildCmdHelper.phase_glue_engine($id, prep.terminal_ids, bld.terminal_ids, cfg.baseline, cfg.hosts)
        $cmds = List.concat($cmds, blg.cmds)
        $id = blg.next_id

        blh = BuildCmdHelper.phase_hosts_engine($id, blg.terminal_ids, $zig_prior, cfg.baseline, cfg.hosts, cfg.optimize)
        $cmds = List.concat($cmds, blh.cmds)
        $id = blh.next_id
        $zig_prior = blh.terminal_ids

        blb = BuildCmdHelper.phase_bundle_engine($id, blh.terminal_ids, cfg.baseline, cfg.hosts)
        $cmds = List.concat($cmds, blb.cmds)
        $id = blb.next_id
        $bundle_terms = List.concat($bundle_terms, blb.terminal_ids)

        for e in cfg.engines {

            d = BuildCmdHelper.phase_dump($id, prep.terminal_ids, e)
            $cmds = List.concat($cmds, d.cmds)
            $id = d.next_id

            g = BuildCmdHelper.phase_glue_engine($id, prep.terminal_ids, d.terminal_ids, e, cfg.hosts)
            $cmds = List.concat($cmds, g.cmds)
            $id = g.next_id

            h = BuildCmdHelper.phase_hosts_engine($id, g.terminal_ids, $zig_prior, e, cfg.hosts, cfg.optimize)
            $cmds = List.concat($cmds, h.cmds)
            $id = h.next_id
            $zig_prior = h.terminal_ids

            b = BuildCmdHelper.phase_bundle_engine($id, h.terminal_ids, e, cfg.hosts)
            $cmds = List.concat($cmds, b.cmds)
            $id = b.next_id
            $bundle_terms = List.concat($bundle_terms, b.terminal_ids)
        }

        pub = BuildCmdHelper.phase_publish($id, $bundle_terms, cfg.baseline, cfg.engines, cfg.publish)
        $cmds = List.concat($cmds, pub.cmds)


        graph = Build.graph($cmds)

        graph
    }


    # =============================================================================
    # Shell helpers
    # =============================================================================

    sh_dollar_brace : Str -> Str
    sh_dollar_brace = |inner| Str.concat("$", Str.concat("{", Str.concat(inner, "}")))

    # find_replace_sh_script : Str, List(ReplacePair) -> Str
    # find_replace_sh_script = |file, pairs| {
    #     var $parts = [
    #         "set -eu\n",
    #         "FILE='",
    #         file,
    #         "'\n",
    #         "if [ ! -f \"$FILE\" ]; then\n",
    #         "  echo \"[find_replace] missing file: $FILE\" >&2\n",
    #         "  exit 1\n",
    #         "fi\n",
    #         "replace_first() {\n",
    #         "  _body=\"$1\"\n",
    #         "  _find=\"$2\"\n",
    #         "  _repl=\"$3\"\n",
    #         "  awk -v bodyf=\"$_body\" -v findf=\"$_find\" -v replf=\"$_repl\" '\n",
    #         "    function readfile(f,    s, line) {\n",
    #         "      s = \"\"\n",
    #         "      while ((getline line < f) > 0)\n",
    #         "        s = s line ORS\n",
    #         "      close(f)\n",
    #         "      return s\n",
    #         "    }\n",
    #         "    BEGIN {\n",
    #         "      find = readfile(findf)\n",
    #         "      repl = readfile(replf)\n",
    #         "      body = readfile(bodyf)\n",
    #         "      while (length(body) > 0 && substr(body, length(body), 1) == ORS)\n",
    #         "        body = substr(body, 1, length(body) - 1)\n",
    #         "      while (length(find) > 0 && substr(find, length(find), 1) == ORS)\n",
    #         "        find = substr(find, 1, length(find) - 1)\n",
    #         "      while (length(repl) > 0 && substr(repl, length(repl), 1) == ORS)\n",
    #         "        repl = substr(repl, 1, length(repl) - 1)\n",
    #         "      idx = index(body, find)\n",
    #         "      if (idx == 0) {\n",
    #         "        print \"[find_replace] pattern not found in \" bodyf > \"/dev/stderr\"\n",
    #         "        exit 1\n",
    #         "      }\n",
    #         "      out = substr(body, 1, idx - 1) repl substr(body, idx + length(find))\n",
    #         "      printf \"%s\", out > bodyf \".new\"\n",
    #         "    }\n",
    #         "  '\n",
    #         "  mv \"$_body.new\" \"$_body\"\n",
    #         "}\n",
    #     ]
    #     var $i = 0.U64
    #     for p in pairs {
    #         i_str = $i.to_str()
    #         $parts = List.concat(
    #             $parts,
    #             [
    #                 "cat >\"$FILE.find_",
    #                 i_str,
    #                 "\" <<'ENDFIND'\n",
    #                 p.find,
    #                 "\nENDFIND\n",
    #                 "cat >\"$FILE.repl_",
    #                 i_str,
    #                 "\" <<'ENDREPL'\n",
    #                 p.replace,
    #                 "\nENDREPL\n",
    #                 "replace_first \"$FILE\" \"$FILE.find_",
    #                 i_str,
    #                 "\" \"$FILE.repl_",
    #                 i_str,
    #                 "\"\n",
    #                 "rm -f \"$FILE.find_",
    #                 i_str,
    #                 "\" \"$FILE.repl_",
    #                 i_str,
    #                 "\"\n",
    #             ],
    #         )
    #         $i = $i + 1
    #     }
    #     $parts = List.concat($parts, ["printf '%s\\n' \"patched $FILE\"\n"])
    #     Str.join_with($parts, "")
    # }

    # find_replace_cmd : TaskId, List(TaskId), Str, List(ReplacePair), Str -> Cmd
    # find_replace_cmd = |id, depends_on, file, pairs, description| {
    #     script = find_replace_sh_script(file, pairs)
    #     Build.cmd({
    #         id,
    #         depends_on,
    #         inputs: [file],
    #         outputs: [file],
    #         program: "sh",
    #         args: ["-c", script],
    #         description,
    #         cwd: "",
    #         env: [],
    #     })
    # }

    # =============================================================================
    # Phases
    # =============================================================================

    phase_prepare : TaskId, Engine, List(Engine) -> PhaseResult
    phase_prepare = |start_id, baseline, engines| {
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

        bldirs = [
            engine_dump_dir(baseline),
            engine_platform_dir(baseline),
            "${engine_platform_dir(baseline)}/targets",
            engine_glue_dir(baseline),
            engine_bundle_dir(baseline),
        ]
        for bld in bldirs {
            c = Build.cmd({
                id: $id,
                depends_on: $clean_ids,
                inputs: [],
                outputs: [],
                program: "mkdir",
                args: ["-p", bld],
                description: "mkdir -p ${bld}",
                cwd: "",
                env: [],
            })
            $cmds = $cmds.append(c)
            $terminals = $terminals.append($id)
            $id = $id + 1
        }

        { cmds: $cmds, terminal_ids: $terminals, next_id: $id }
    }

    phase_dump : TaskId, List(TaskId), Engine -> PhaseResult
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
            program: eng.to_cli_name(),
            args: ["--headless", "--dump-gdextension-interface", "--dump-extension-api"],
            description: "dump (${eng.to_cli_name()} ${eng.to_path_slug()})",
            cwd: dump_dir,
            env: [],
        })
        { cmds: [dump], terminal_ids: [start_id], next_id: start_id + 1 }
    }

    phase_glue_engine : TaskId, List(TaskId), List(TaskId), Engine, List(CpuArchOS) -> PhaseResult
    phase_glue_engine = |start_id, prepare_ids, dump_ids, eng, hosts| {
        #slug = eng.to_path_slug()
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
                "--engine=${eng.to_name()}",
            ],
            description: "Generate gdextension_interface (${eng.to_name()})",
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
                "--engine=${eng.to_name()}",
                "--targets=${Str.join_with(hosts.map(|h| h.to_name()), ",")}",
            ],
            description: "Generate extension_api platform (${eng.to_name()})",
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
            description: "roc glue (${eng.to_name()})",
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
            "patch glue marker (${eng.to_name()})",
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
            description: "note patched glue (${eng.to_name()})",
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
            description: "cp gde_call.zig (${eng.to_name()})",
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
            description: "zig test gdextension_interface (${eng.to_name()})",
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
            description: "roc check platform (${eng.to_name()})",
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

    zig_host_args : CpuArchOS, Optimize, Str -> List(Str)
    zig_host_args = |cpu_arch_os, opt, out_path| {
        host = Host.to_target(cpu_arch_os)
        o = Host.optimize_str(opt)
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
    phase_hosts_engine : TaskId, List(TaskId), List(TaskId), Engine, List(CpuArchOS), Optimize -> PhaseResult
    phase_hosts_engine = |start_id, glue_ids, prior_ids, eng, hosts, opt| {
        var $id = start_id
        var $cmds = []
        var $prev = List.concat(glue_ids, prior_ids)
        var $last = $prev

        for h in hosts {
            out_dir = "${engine_platform_dir(eng)}/targets/${h.to_name()}"
            out_path = "${out_dir}/${Host.to_target(h).lib_file}"

            mk = Build.cmd({
                id: $id,
                depends_on: $prev,
                inputs: [],
                outputs: [],
                program: "mkdir",
                args: ["-p", out_dir],
                description: "mkdir host target ${eng.to_name()}: ${eng.to_path_slug()}/${h.to_name()}",
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
                description: "compile host ${eng.to_name()}: ${eng.to_path_slug()}/${h.to_name()}",
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

    phase_bundle_engine : TaskId, List(TaskId), Engine, List(CpuArchOS) -> PhaseResult
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
            description: "mkdir bundle-out (${eng.to_name()})",
            cwd: "",
            env: [],
        })
        $cmds = $cmds.append(mk)
        mk_id = $id
        $id = $id + 1

        var $bundle_args = ["bundle", "main.roc"]
        for h in hosts {
            $bundle_args = $bundle_args.append("targets/${h.to_name()}/${Host.to_target(h).lib_file}")
        }

        bund = Build.cmd({
            id: $id,
            depends_on: [mk_id],
            inputs: ["${plat}/main.roc"],
            outputs: [],
            program: "roc",
            args: $bundle_args,
            description: "roc bundle (${eng.to_name()})",
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
                "mkdir -p bundle-out/${eng.to_path_slug()} && mv -f platform-out/${eng.to_path_slug()}/*.tar.zst bundle-out/${eng.to_path_slug()}/",
            ],
            description: "move bundle tar.zst (${eng.to_name()})",
            cwd: "",
            env: [],
        })
        $cmds = $cmds.append(move)
        move_id = $id
        $id = $id + 1

        { cmds: $cmds, terminal_ids: [move_id], next_id: $id }
    }

    ## Stage labeled assets + NOTES.md, then gh release create.
    ## Asset name: <slug>-<original-hash>.tar.zst
    ## Roc only needs the URL body; filename is for humans.
    ##
    ## Important: never put bash `${name}` inside a Roc string literal.
    ## Always build it with sh_dollar_brace("name").
    phase_publish : TaskId, List(TaskId), Engine, List(Engine), PublishOpts -> PhaseResult
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
        $stage_parts : List(Str)
        var $stage_parts = []
        for e in engines {
            is_base =
                if e.to_name() == baseline.to_name() {
                    "yes"
                } else {
                    "no"
                }
            $stage_parts =
                List.concat(
                    $stage_parts,
                    [
                        "stage_engine '",
                        e.to_path_slug(),
                        "' '",
                        e.to_name(),
                        "' '",
                        is_base,
                        "'\n",
                    ],
                )
        }
        stage_loop = Str.join_with($stage_parts, "")

        # Bash ${…} fragments (built outside Roc interpolations)
        b_token = sh_dollar_brace("GITHUB_TOKEN:-")
        b_repo_env = sh_dollar_brace("GITHUB_REPOSITORY:-")
        b_files0 = sh_dollar_brace("_files[0]")
        b_assets_len = sh_dollar_brace("#ASSETS[@]")
        b_assets_all = sh_dollar_brace("ASSETS[@]")
        b_labels_i = sh_dollar_brace("LABELS[$i]")
        b_slugs_i = sh_dollar_brace("SLUGS[$i]")
        b_assets_i = sh_dollar_brace("ASSETS[$i]")
        b_urls_i = sh_dollar_brace("URLS[$i]")
        b_is_base_i = sh_dollar_brace("IS_BASE[$i]")
        b_slug = sh_dollar_brace("_slug")
        b_hash = sh_dollar_brace("_hash")
        b_lab = sh_dollar_brace("_lab")
        b_url = sh_dollar_brace("_url")
        b_base = sh_dollar_brace("_base")
        b_repo = sh_dollar_brace("REPO")
        b_tag = sh_dollar_brace("TAG")
        b_sha = sh_dollar_brace("SHA")
        b_dest = sh_dollar_brace("_dest")
        b_src = sh_dollar_brace("_src")
        b_dir = sh_dollar_brace("_dir")
        b_label = sh_dollar_brace("_label")

        script =
            Str.join_with(
                [
                    "set -eu\n",
                    "if [ -z \"",
                    b_token,
                    "\" ]; then\n",
                    "  echo \"[publish] GITHUB_TOKEN required\" >&2\n",
                    "  exit 1\n",
                    "fi\n",
                    "if ! command -v gh >/dev/null 2>&1; then\n",
                    "  echo \"[publish] gh CLI not found\" >&2\n",
                    "  exit 1\n",
                    "fi\n",
                    "REPO=\"",
                    b_repo_env,
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
                    "URLS=()\n",
                    "LABELS=()\n",
                    "SLUGS=()\n",
                    "IS_BASE=()\n",
                    "\n",
                    "stage_engine() {\n",
                    "  _slug=\"$1\"\n",
                    "  _label=\"$2\"\n",
                    "  _base=\"$3\"\n",
                    "  _dir=\"bundle-out/",
                    b_slug,
                    "\"\n",
                    "  if [ ! -d \"",
                    b_dir,
                    "\" ]; then\n",
                    "    echo \"[publish] missing ",
                    b_dir,
                    "\" >&2\n",
                    "    return 0\n",
                    "  fi\n",
                    "  # shellcheck disable=SC2206\n",
                    "  _files=(\"",
                    b_dir,
                    "\"/*.tar.zst)\n",
                    "  if [ ! -e \"",
                    b_files0,
                    "\" ]; then\n",
                    "    echo \"[publish] no .tar.zst under ",
                    b_dir,
                    "\" >&2\n",
                    "    return 0\n",
                    "  fi\n",
                    "  _src=\"",
                    b_files0,
                    "\"\n",
                    "  _hash=$(basename \"",
                    b_src,
                    "\" .tar.zst)\n",
                    "  _dest=\"$STAGING/",
                    b_slug,
                    "-",
                    b_hash,
                    ".tar.zst\"\n",
                    "  cp -f \"",
                    b_src,
                    "\" \"",
                    b_dest,
                    "\"\n",
                    "  ASSETS+=(\"",
                    b_dest,
                    "\")\n",
                    "  URLS+=(\"https://github.com/",
                    b_repo,
                    "/releases/download/",
                    b_tag,
                    "/$(basename \"",
                    b_dest,
                    "\")\")\n",
                    "  LABELS+=(\"",
                    b_label,
                    "\")\n",
                    "  SLUGS+=(\"",
                    b_slug,
                    "\")\n",
                    "  IS_BASE+=(\"",
                    b_base,
                    "\")\n",
                    "  echo \"[publish] staged $(basename \"",
                    b_dest,
                    "\")\"\n",
                    "}\n",
                    "\n",
                    stage_loop,
                    "\n",
                    "if [ ",
                    b_assets_len,
                    " -eq 0 ]; then\n",
                    "  echo \"[publish] no assets to upload\" >&2\n",
                    "  exit 1\n",
                    "fi\n",
                    "\n",
                    "# ---- NOTES.md ----\n",
                    "{\n",
                    "  echo \"## godot-roc ",
                    b_tag,
                    "\"\n",
                    "  echo\n",
                    "  echo \"Commit: \\`",
                    b_sha,
                    "\\`\"\n",
                    "  echo\n",
                    "  echo \"### Assets\"\n",
                    "  echo\n",
                    "  i=0\n",
                    "  while [ \"$i\" -lt ",
                    b_assets_len,
                    " ]; do\n",
                    "    echo \"- **",
                    b_labels_i,
                    "** (\\`",
                    b_slugs_i,
                    "\\`)\"\n",
                    "    echo \"  - file: \\`$(basename \"",
                    b_assets_i,
                    "\")\\`\"\n",
                    "    echo \"  - url: \\`",
                    b_urls_i,
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
                    b_assets_len,
                    " ]; do\n",
                    "    _lab=\"",
                    b_labels_i,
                    "\"\n",
                    "    _url=\"",
                    b_urls_i,
                    "\"\n",
                    "    _base=\"",
                    b_is_base_i,
                    "\"\n",
                    "    echo \"#### ",
                    b_lab,
                    "\"\n",
                    "    echo\n",
                    "    echo '```roc'\n",
                    "    echo 'app [ready!, process!, scene_init!, physics_process!] {'\n",
                    "    if [ \"",
                    b_base,
                    "\" = \"yes\" ]; then\n",
                    "      echo \"    # [baseline] ",
                    b_lab,
                    "\"\n",
                    "      echo \"    pf: platform \\\"",
                    b_url,
                    "\\\",\"\n",
                    "    else\n",
                    "      echo \"    # ",
                    b_lab,
                    "\"\n",
                    "      echo \"    pf: platform \\\"",
                    b_url,
                    "\\\",\"\n",
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
                    b_assets_len,
                    " ]; do\n",
                    "    _lab=\"",
                    b_labels_i,
                    "\"\n",
                    "    _url=\"",
                    b_urls_i,
                    "\"\n",
                    "    _base=\"",
                    b_is_base_i,
                    "\"\n",
                    "    if [ \"",
                    b_base,
                    "\" = \"yes\" ]; then\n",
                    "      echo \"    # [baseline] ",
                    b_lab,
                    "\"\n",
                    "      echo \"    pf: platform \\\"",
                    b_url,
                    "\\\",\"\n",
                    "    else\n",
                    "      echo \"    # ",
                    b_lab,
                    "\"\n",
                    "      echo \"    # pf: platform \\\"",
                    b_url,
                    "\\\",\"\n",
                    "    fi\n",
                    "    i=$((i + 1))\n",
                    "  done\n",
                    "  echo '}'\n",
                    "  echo '```'\n",
                    "} >\"$NOTES\"\n",
                    "\n",
                    "echo \"[publish] release ",
                    b_tag,
                    " (",
                    b_assets_len,
                    " assets)\"\n",
                    "gh release create \"",
                    b_tag,
                    "\" ",
                    b_assets_all,
                    " \\\n",
                    "  --title \"godot-roc ",
                    b_tag,
                    "\" \\\n",
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



}
