#!/usr/bin/env roc

#
# CI smoke: godot4.5 × x64musl only
#
#   roc run scripts/ci.roc
#   nix run github:lukewilliamboswell/roc-blueprint/0.5.0 -- run ci
#

app [main!] {
    pf: platform "https://github.com/scottc/roc-build/releases/download/v0.1.0-rc1/EG89xVCPEj7M71tj23bNmENBi3uHAbavsWQL9NuTV8vo.tar.zst",
}

import pf.Build exposing [Cmd, TaskId]
import pf.Log

import BuildCmdHelper exposing [PhaseResult, ReplacePair]



# =============================================================================
# main!
# =============================================================================

main! : List(Str) => Try({}, [Exit(I32)])
main! = |_args| {
    #Log.info!("CI smoke — ${BuildCmdHelper.ci_engine.to_name()} × ${BuildCmdHelper.ci_cpu_arch_os.to_name()} (-O${BuildCmdHelper.opt_to_str(BuildCmdHelper.ci_optimize)})")

    graph = BuildCmdHelper.to_ci_build_graph()

    match Build.run!(graph) {
        Ok({}) => {
            Log.info!("smoke ok")
            # Log.info!("  platform: ${BuildCmdHelper.ci_platform_out}")
            # Log.info!("  app:      ${BuildCmdHelper.ci_smoke_proj}")
            # Log.info!("  so:       ${BuildCmdHelper.ci_smoke_proj}/my_game.so")
            Ok({})
        }
        Err(BuildFailed(msg)) => {
            Log.error!(msg)
            Err(Exit(1))
        }
    }
}
