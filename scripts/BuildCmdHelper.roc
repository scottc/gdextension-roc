import pf.Build
import pf.BuildCmd
import pf.Mem
# import pf.Host exposing [BuildGraph, Limits] #TODO: import

import modules/HostTarget exposing [Optimize] #TODO: rename conflicting local module "HostTargets" or something.
import modules/Args exposing [PublishOpts]
import modules/Engine
import modules/CpuArchOS

BuildCmdHelper := {}.{
    PhaseResult : {
        cmds : List(BuildCmd),
        terminals : List(BuildCmd),
    }

    ReplacePair : { find : Str, replace : Str }

    PubConfig : {
        baseline : Engine,
        engines : List(Engine),
        hosts : List(CpuArchOS),
        optimize : Optimize,
        publish : PublishOpts,
        limits : Limits,
    }

    # -------------------------------------------------------------------------
    # Hardware / overall scheduler limits
    # max_memory / max_parallel of 0 = unlimited (host treats as no cap)
    # -------------------------------------------------------------------------

    ## TODO: move Limits struct into build platform, it belongs there, not here.
    Limits : { max_memory : U64, max_parallel : U64 }

    ## Default Ubuntu GHA runner (~7 GiB RAM, 2 vCPU).
    ## Leave headroom for the OS / runner agent.
    default_limits : Limits
    default_limits = {
        max_memory: Mem.gb(6),
        max_parallel: 2,
    }

    ## Build a Limits from explicit values (0 = unlimited on the host).
    limits : U64, U64 -> Limits
    limits = |max_memory, max_parallel| {
        max_memory,
        max_parallel,
    }

    # -------------------------------------------------------------------------
    # Per-task memory budgets (declared reservation for the scheduler)
    # Aim ~50–75% of true peak so packing stays safe without over-serializing.
    # -------------------------------------------------------------------------

    budget_shell : U64
    budget_shell = Mem.mb(64) # rm, mkdir, cp, sh one-liners, find_replace

    budget_engine_dump : U64
    budget_engine_dump = Mem.mb(768) # godot/redot --dump-*

    budget_roc_codegen : U64
    budget_roc_codegen = Mem.mb(512) # roc run scripts/*.generate.roc

    budget_roc_glue : U64
    budget_roc_glue = Mem.mb(512)

    budget_roc_check : U64
    budget_roc_check = Mem.mb(384)

    budget_zig_test : U64
    budget_zig_test = Mem.mb(512)

    budget_zig_host : U64
    budget_zig_host = Mem.gb(2) # zig build-lib / build-obj host

    budget_roc_build : U64
    budget_roc_build = Mem.mb(768) # roc build smoke app

    budget_roc_bundle : U64
    budget_roc_bundle = Mem.mb(512)

    budget_publish : U64
    budget_publish = Mem.mb(128) # gh release + staging script

    to_ci_build_graph : Limits => _ #BuildGraph
    to_ci_build_graph = |lims| {
        prep = BuildCmdHelper.ci_phase_prepare({})
        d = BuildCmdHelper.ci_phase_dump(prep.terminals)
        g = BuildCmdHelper.ci_phase_glue(prep.terminals, d.terminals)
        h = BuildCmdHelper.ci_phase_host(g.terminals)
        w = BuildCmdHelper.ci_phase_workspace(h.terminals)
        s = BuildCmdHelper.ci_phase_smoke(w.terminals)

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

        Build.graph_with(cmds, lims)
    }

    # =============================================================================
    # Fixed smoke matrix (no CLI matrix)
    # =============================================================================

    ci_engine : Engine
    ci_engine = Engine.Godot({ major: 4, minor: 3 })
    #ci_engine = Engine.Blazium({ major: 0, minor: 6 })

    ci_cpu_arch_os : CpuArchOS
    ci_cpu_arch_os = CpuArchOS.X64musl

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

    find_replace_cmd : List(BuildCmd), Str, List(ReplacePair), Str -> BuildCmd
    find_replace_cmd = |depends_on, file, pairs, description| {
        script = find_replace_sh_script(file, pairs)
        BuildCmd.new({
            program: "sh",
            args: ["-c", script],
            description,
        }).depends_on(depends_on).with_memory(budget_shell)
    }

    # =============================================================================
    # CI phases
    # =============================================================================

    ci_phase_prepare : {} -> PhaseResult
    ci_phase_prepare = |_| {
        var $cmds = []
        var $clean = []

        roots = [
            "dump-out",
            "platform-out",
            "host/glue-out",
            "smoke-out",
        ]
        for r in roots {
            c = BuildCmd.new({
                program: "rm",
                args: ["-rf", r],
                description: "rm -rf ${r}",
            }).with_memory(budget_shell)
            $cmds = $cmds.append(c)
            $clean = $clean.append(c)
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
            c = BuildCmd.new({
                program: "mkdir",
                args: ["-p", d],
                description: "mkdir -p ${d}",
            }).depends_on($clean).with_memory(budget_shell)
            $cmds = $cmds.append(c)
            $terminals = $terminals.append(c)
        }

        { cmds: $cmds, terminals: $terminals }
    }

    ci_phase_dump : List(BuildCmd) -> PhaseResult
    ci_phase_dump = |prepare_cmds| {
        dump =
            BuildCmd.new({
                program: ci_engine.to_cli_name(),
                args: ["--headless", "--dump-gdextension-interface", "--dump-extension-api"],
                description: "dump gdextension + extension_api (${ci_engine.to_cli_name()} <- ${ci_engine.to_name()})",
            })
            .depends_on(prepare_cmds)
            .with_cwd(ci_dump_out)
            .with_memory(budget_engine_dump)
        { cmds: [dump], terminals: [dump] }
    }

    ci_phase_glue : List(BuildCmd), List(BuildCmd) -> PhaseResult
    ci_phase_glue = |prepare_cmds, dump_cmds| {
        var $cmds = []
        deps = List.concat(prepare_cmds, dump_cmds)

        gen_host =
            BuildCmd.new({
                program: "roc",
                args: [
                    "run",
                    "scripts/host.generate.roc",
                    "--",
                    #TODO: pass --baseline & --engines flags?
                    #"--engine=${ci_engine.to_name()}",
                ],
                description: "Generate gdextension_interface",
            }).depends_on(deps).with_memory(budget_roc_codegen)
        $cmds = $cmds.append(gen_host)

        gen_iface =
            BuildCmd.new({
                program: "roc",
                args: [
                    "run",
                    "scripts/gdextension_interface.generate.roc",
                    "--",
                    "--engine=${ci_engine.to_name()}",
                ],
                description: "Generate gdextension_interface (${ci_engine.to_name()})",
            }).depends_on(deps).with_memory(budget_roc_codegen)
        $cmds = $cmds.append(gen_iface)

        gen_api =
            BuildCmd.new({
                program: "roc",
                args: [
                    "run",
                    "scripts/extension_api.generate.roc",
                    "--",
                    "--engine=${ci_engine.to_name()}",
                    "--targets=${ci_cpu_arch_os.to_name()}",
                ],
                description: "Generate extension_api platform (${ci_engine.to_name()})",
            }).depends_on(deps).with_memory(budget_roc_codegen)
        $cmds = $cmds.append(gen_api)

        glue =
            BuildCmd.new({
                program: "roc",
                args: [
                    "glue",
                    ci_glue_spec,
                    ci_glue_out,
                    "${ci_platform_out}/main.roc",
                ],
                description: "roc glue (${ci_engine.to_name()})",
            }).depends_on([gen_api]).with_memory(budget_roc_glue)
        $cmds = $cmds.append(glue)

        patch = find_replace_cmd(
            [glue],
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

        abi_note =
            BuildCmd.new({
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
            }).depends_on([patch]).with_memory(budget_shell)
        $cmds = $cmds.append(abi_note)


        zt =
            BuildCmd.new({
                program: "zig",
                args: ["test", "${ci_glue_out}/gdextension_interface.zig"],
                description: "zig test gdextension_interface (${ci_engine.to_name()})",
            }).depends_on([gen_iface]).with_memory(budget_zig_test)
        $cmds = $cmds.append(zt)

        rc =
            BuildCmd.new({
                program: "roc",
                args: ["check", "${ci_platform_out}/main.roc"],
                description: "roc check platform (${ci_engine.to_name()})",
            }).depends_on([gen_api]).with_memory(budget_roc_check)
        $cmds = $cmds.append(rc)

        {
            cmds: $cmds,
            terminals: [abi_note, zt, rc],
        }
    }

    ci_phase_host : List(BuildCmd) -> PhaseResult
    ci_phase_host = |glue_cmds| {
        out_dir = "${ci_platform_out}/targets/${ci_cpu_arch_os.to_name()}"
        out_path = "${out_dir}/${HostTarget.to_target(ci_cpu_arch_os).lib_file}"

        mk =
            BuildCmd.new({
                program: "mkdir",
                args: ["-p", out_dir],
                description: "mkdir host target ${ci_engine.to_name()} ${ci_engine.to_path_slug()}/${ci_cpu_arch_os.to_name()}",
            }).depends_on(glue_cmds).with_memory(budget_shell)

        compile =
            BuildCmd.new({
                program: "zig",
                args: [
                    "build-lib",
                    "host/host.zig",
                    "-target",
                    HostTarget.to_target(ci_cpu_arch_os).zig_triple,
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
            }).depends_on([mk]).with_memory(budget_zig_host)

        { cmds: [mk, compile], terminals: [compile] }
    }

    ci_phase_workspace : List(BuildCmd) -> PhaseResult
    ci_phase_workspace = |host_cmds| {
        var $cmds = []

        mk =
            BuildCmd.new({
                program: "mkdir",
                args: ["-p", ci_smoke_proj],
                description: "mkdir smoke project (${ci_engine.to_name()})",
            }).depends_on(host_cmds).with_memory(budget_shell)
        $cmds = $cmds.append(mk)

        cp_tpl =
            BuildCmd.new({
                program: "cp",
                args: ["-a", "templates/ci/.", "${ci_smoke_proj}/"],
                description: "cp template game (${ci_engine.to_name()})",
            }).depends_on([mk]).with_memory(budget_shell)
        $cmds = $cmds.append(cp_tpl)

        cp_plat =
            BuildCmd.new({
                program: "cp",
                args: ["-a", "${ci_platform_out}/.", "${ci_smoke_proj}/platform/"],
                description: "cp local platform into smoke (${ci_engine.to_name()})",
            }).depends_on([cp_tpl]).with_memory(budget_shell)
        $cmds = $cmds.append(cp_plat)

        patch = find_replace_cmd(
            [cp_plat],
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

        { cmds: $cmds, terminals: [patch] }
    }

    ci_phase_smoke : List(BuildCmd) -> PhaseResult
    ci_phase_smoke = |ws_cmds| {
        main_roc = "${ci_smoke_proj}/main.roc"
        out_so = "${ci_smoke_proj}/my_game.so"

        desk =
            BuildCmd.new({
                program: "roc",
                args: [
                    "build",
                    main_roc,
                    "--target=${ci_cpu_arch_os.to_name()}",
                    "--no-cache",
                    "--output=${out_so}",
                ],
                description: "roc build desktop smoke ${ci_engine.to_name()} (${ci_engine.to_path_slug()}/${ci_cpu_arch_os.to_name()})",
            }).depends_on(ws_cmds).with_memory(budget_roc_build)

        { cmds: [desk], terminals: [desk] }
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

    # =============================================================================
    # Publish graph
    # =============================================================================

    to_publish_build_graph : PubConfig -> _ # Host.BuildGraph
    to_publish_build_graph = |cfg| {
        prep = BuildCmdHelper.phase_prepare(cfg.baseline, cfg.engines)
        var $cmds = prep.cmds
        var $bundle_terms = []

        $zig_prior : List(BuildCmd)
        var $zig_prior = []

        bld = BuildCmdHelper.phase_dump(prep.terminals, cfg.baseline)
        $cmds = List.concat($cmds, bld.cmds)

        gen_host =
            BuildCmd.new({
                program: "roc",
                args: [
                    "run",
                    "scripts/host.generate.roc",
                    "--",
                    #TODO: take --baseline & --engines flags?
                    #"--engine=${eng.to_name()}",
                ],
                description: "Generate host",
            }).depends_on(bld.cmds).with_memory(budget_roc_codegen)
        $cmds = $cmds.append(gen_host)

        blg = BuildCmdHelper.phase_glue_engine(prep.terminals, bld.terminals, cfg.baseline, cfg.hosts)
        $cmds = List.concat($cmds, blg.cmds)

        blh = BuildCmdHelper.phase_hosts_engine(blg.terminals, $zig_prior, cfg.baseline, cfg.hosts, cfg.optimize)
        $cmds = List.concat($cmds, blh.cmds)
        $zig_prior = blh.terminals

        blb = BuildCmdHelper.phase_bundle_engine(blh.terminals, cfg.baseline, cfg.hosts)
        $cmds = List.concat($cmds, blb.cmds)
        $bundle_terms = List.concat($bundle_terms, blb.terminals)

        for e in cfg.engines {
            d = BuildCmdHelper.phase_dump(prep.terminals, e)
            $cmds = List.concat($cmds, d.cmds)

            g = BuildCmdHelper.phase_glue_engine(prep.terminals, d.terminals, e, cfg.hosts)
            $cmds = List.concat($cmds, g.cmds)

            h = BuildCmdHelper.phase_hosts_engine(g.terminals, $zig_prior, e, cfg.hosts, cfg.optimize)
            $cmds = List.concat($cmds, h.cmds)
            $zig_prior = h.terminals

            b = BuildCmdHelper.phase_bundle_engine(h.terminals, e, cfg.hosts)
            $cmds = List.concat($cmds, b.cmds)
            $bundle_terms = List.concat($bundle_terms, b.terminals)
        }

        pub = BuildCmdHelper.phase_publish($bundle_terms, cfg.baseline, cfg.engines, cfg.publish)
        $cmds = List.concat($cmds, pub.cmds)

        Build.graph_with($cmds, cfg.limits)
    }

    # =============================================================================
    # Shell helpers (publish)
    # =============================================================================

    sh_dollar_brace : Str -> Str
    sh_dollar_brace = |inner| Str.concat("$", Str.concat("{", Str.concat(inner, "}")))

    # =============================================================================
    # Publish phases
    # =============================================================================

    phase_prepare : Engine, List(Engine) -> PhaseResult
    phase_prepare = |baseline, engines| {
        var $cmds = []
        var $clean = []

        roots = ["dump-out", "platform-out", "host/glue-out", "bundle-out", "release-assets"]
        for r in roots {
            c = BuildCmd.new({
                program: "rm",
                args: ["-rf", r],
                description: "rm -rf ${r}",
            }).with_memory(budget_shell).with_memory(budget_shell)
            $cmds = $cmds.append(c)
            $clean = $clean.append(c)
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
                c = BuildCmd.new({
                    program: "mkdir",
                    args: ["-p", d],
                    description: "mkdir -p ${d}",
                }).depends_on($clean).with_memory(budget_shell)
                $cmds = $cmds.append(c)
                $terminals = $terminals.append(c)
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
            c = BuildCmd.new({
                program: "mkdir",
                args: ["-p", bld],
                description: "mkdir -p ${bld}",
            }).depends_on($clean).with_memory(budget_shell)
            $cmds = $cmds.append(c)
            $terminals = $terminals.append(c)
        }

        { cmds: $cmds, terminals: $terminals }
    }

    phase_dump : List(BuildCmd), Engine -> PhaseResult
    phase_dump = |prepare_cmds, eng| {
        dump_dir = engine_dump_dir(eng)
        dump =
            BuildCmd.new({
                program: eng.to_cli_name(),
                args: ["--headless", "--dump-gdextension-interface", "--dump-extension-api"],
                description: "dump (${eng.to_cli_name()} ${eng.to_path_slug()})",
            })
            .depends_on(prepare_cmds)
            .with_cwd(dump_dir)
            .with_memory(budget_engine_dump)
        { cmds: [dump], terminals: [dump] }
    }

    phase_glue_engine : List(BuildCmd), List(BuildCmd), Engine, List(CpuArchOS) -> PhaseResult
    phase_glue_engine = |prepare_cmds, dump_cmds, eng, hosts| {
        glue_dir = engine_glue_dir(eng)
        platform_dir = engine_platform_dir(eng)
        var $cmds = []
        deps = List.concat(prepare_cmds, dump_cmds)

        gen_iface =
            BuildCmd.new({
                program: "roc",
                args: [
                    "run",
                    "scripts/gdextension_interface.generate.roc",
                    "--",
                    "--engine=${eng.to_name()}",
                ],
                description: "Generate gdextension_interface (${eng.to_name()})",
            }).depends_on(deps).with_memory(budget_roc_codegen)
        $cmds = $cmds.append(gen_iface)

        gen_api =
            BuildCmd.new({
                program: "roc",
                args: [
                    "run",
                    "scripts/extension_api.generate.roc",
                    "--",
                    "--engine=${eng.to_name()}",
                    "--targets=${Str.join_with(hosts.map(|h| h.to_name()), ",")}",
                ],
                description: "Generate extension_api platform (${eng.to_name()})",
            }).depends_on(deps).with_memory(budget_roc_codegen)
        $cmds = $cmds.append(gen_api)

        glue =
            BuildCmd.new({
                program: "roc",
                args: [
                    "glue",
                    glue_spec,
                    glue_dir,
                    "${platform_dir}/main.roc",
                ],
                description: "roc glue (${eng.to_name()})",
            }).depends_on([gen_api]).with_memory(budget_roc_glue)
        $cmds = $cmds.append(glue)

        patch = find_replace_cmd(
            [glue],
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

        abi_note =
            BuildCmd.new({
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
            }).depends_on([patch]).with_memory(budget_shell)
        $cmds = $cmds.append(abi_note)

        cp_gde =
            BuildCmd.new({
                program: "cp",
                args: ["host/gde_call.template.zig", "${glue_dir}/gde_call.zig"],
                description: "cp gde_call.zig (${eng.to_name()})",
            }).depends_on([gen_iface]).with_memory(budget_shell)
        $cmds = $cmds.append(cp_gde)

        zt =
            BuildCmd.new({
                program: "zig",
                args: ["test", "${glue_dir}/gdextension_interface.zig"],
                description: "zig test gdextension_interface (${eng.to_name()})",
            }).depends_on([gen_iface]).with_memory(budget_zig_test)
        $cmds = $cmds.append(zt)

        rc =
            BuildCmd.new({
                program: "roc",
                args: ["check", "${platform_dir}/main.roc"],
                description: "roc check platform (${eng.to_name()})",
            }).depends_on([gen_api]).with_memory(budget_roc_check)
        $cmds = $cmds.append(rc)

        {
            cmds: $cmds,
            terminals: [abi_note, cp_gde, zt, rc],
        }
    }

    zig_host_args : CpuArchOS, Optimize, Str -> List(Str)
    zig_host_args = |cpu_arch_os, opt, out_path| {
        host = HostTarget.to_target(cpu_arch_os)
        o = HostTarget.optimize_str(opt)
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

    ## Sequential Zig host compiles (one at a time via depends_on chain).
    phase_hosts_engine : List(BuildCmd), List(BuildCmd), Engine, List(CpuArchOS), Optimize -> PhaseResult
    phase_hosts_engine = |glue_cmds, prior_cmds, eng, hosts, opt| {
        var $cmds = []
        var $prev = List.concat(glue_cmds, prior_cmds)

        $last : List(BuildCmd)
        var $last = $prev

        for h in hosts {
            out_dir = "${engine_platform_dir(eng)}/targets/${h.to_name()}"
            out_path = "${out_dir}/${HostTarget.to_target(h).lib_file}"

            mk =
                BuildCmd.new({
                    program: "mkdir",
                    args: ["-p", out_dir],
                    description: "mkdir host target ${eng.to_name()}: ${eng.to_path_slug()}/${h.to_name()}",
                }).depends_on($prev).with_memory(budget_shell)
            $cmds = $cmds.append(mk)

            c =
                BuildCmd.new({
                    program: "zig",
                    args: zig_host_args(h, opt, out_path),
                    description: "compile host ${eng.to_name()}: ${eng.to_path_slug()}/${h.to_name()}",
                }).depends_on([mk]).with_memory(budget_zig_host)
            $cmds = $cmds.append(c)
            $prev = [c]
            $last = [c]
        }

        { cmds: $cmds, terminals: $last }
    }

    phase_bundle_engine : List(BuildCmd), Engine, List(CpuArchOS) -> PhaseResult
    phase_bundle_engine = |host_cmds, eng, hosts| {
        var $cmds = []
        plat = engine_platform_dir(eng)

        mk =
            BuildCmd.new({
                program: "mkdir",
                args: ["-p", engine_bundle_dir(eng)],
                description: "mkdir bundle-out (${eng.to_name()})",
            }).depends_on(host_cmds).with_memory(budget_shell)
        $cmds = $cmds.append(mk)

        var $bundle_args = ["bundle", "main.roc"]
        for h in hosts {
            $bundle_args = $bundle_args.append("targets/${h.to_name()}/${HostTarget.to_target(h).lib_file}")
        }

        bund =
            BuildCmd.new({
                program: "roc",
                args: $bundle_args,
                description: "roc bundle (${eng.to_name()})",
            })
            .depends_on([mk])
            .with_cwd(plat)
            .with_memory(budget_roc_bundle)
        $cmds = $cmds.append(bund)

        move =
            BuildCmd.new({
                program: "sh",
                args: [
                    "-c",
                    "mkdir -p bundle-out/${eng.to_path_slug()} && mv -f platform-out/${eng.to_path_slug()}/*.tar.zst bundle-out/${eng.to_path_slug()}/",
                ],
                description: "move bundle tar.zst (${eng.to_name()})",
            }).depends_on([bund]).with_memory(budget_shell)
        $cmds = $cmds.append(move)

        { cmds: $cmds, terminals: [move] }
    }

    ## Stage labeled assets + NOTES.md, then gh release create.
    phase_publish : List(BuildCmd), Engine, List(Engine), PublishOpts -> PhaseResult
    phase_publish = |depends_on, baseline, engines, opts| {
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

        cmd =
            BuildCmd.new({
                program: "sh",
                args: ["-c", script],
                description: "GitHub release (labeled assets + notes)",
            }).depends_on(depends_on).with_memory(budget_shell)

        { cmds: [cmd], terminals: [cmd] }
    }
}
