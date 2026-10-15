#!/usr/bin/env roc

#
# Publish platform bundles (no smoke / workspace / game).
# Zig host compiles are sequential (one at a time) to bound RAM.
#
# Defaults:
#   --baseline=godot4.5
#   --engines=godot-stable,redot-stable
#   --targets=all
#   -Doptimize=ReleaseFast
#   --tag=  → nightly-YYYY-MM-DD-<sha7> if omitted
#
# Examples:
#   roc run scripts/publish.roc -- \
#     --baseline=godot4.5 --engines=godot-stable,redot-stable \
#     --targets=x64musl,wasm32 -Doptimize=ReleaseFast \
#     --tag=nightly-2026-10-11-abc1234
#
#   roc run scripts/publish.roc -- \
#     --baseline=godot4.5 --engines=godot-stable,redot-stable \
#     --tag=v0.1.0-rc1 -Doptimize=ReleaseFast
#

app [main!] {
    pf: platform "https://github.com/scottc/roc-build/releases/download/v0.1.0-rc1/EG89xVCPEj7M71tj23bNmENBi3uHAbavsWQL9NuTV8vo.tar.zst",
}

import pf.Build exposing [Cmd, TaskId, BuildGraph]
import pf.Log

import BuildCmdHelper exposing [ReplacePair, PhaseResult, PubConfig]

import modules/Args exposing [PublishOpts]


# import modules/Host exposing [Optimize, LibKind]
# import modules/CpuArchOS
# import modules/Engine
# import modules/Host exposing [HostTarget]

# =============================================================================
# main!
# =============================================================================

main! : List(Str) => Try({}, [BadNumStr, EngineParseError(Str), Exit(I32), ListWasEmpty, MissingRequiredBaselineFlag(Str), MissingRequiredEnginesFlag(Str), MissingRequiredTargetsFlag(Str)])
main! = |args| {
    cfg : PubConfig
    cfg = {
        baseline: Args.parse_baseline_flag_or_godot4_3(args), #TODO: handle error, don't early return these failures.
        engines: Args.parse_engines_flag_or_empty(args),
        hosts: Args.parse_targets_flag_or_auto(args),
        optimize: Args.parse_optimize_flag_or_release_fast(args),
        publish: {
            tag: Args.parse_tag_flag_or_autotag(args)
        },
    }

    Log.info!("Publish — engine × host matrix (Zig hosts sequential)")
    Log.info!("--baseline=${cfg.baseline.to_name()}")
    Log.info!("--engines=")
    for e in cfg.engines {
        Log.info!("  - ${e.to_name()}")
    }
    Log.info!("--targets=")
    for h in cfg.hosts {
        Log.info!("  - ${h.to_name()}")
    }
    Log.info!("--optimize=${Str.inspect(cfg.optimize)}")
    Log.info!("--tag=${Str.inspect(cfg.publish.tag)}")

    #Log.info!("engine=${e.to_path_slug()}")
    graph : BuildGraph
    graph = BuildCmdHelper.to_publish_build_graph(cfg)
    #Log.info!("total cmds=${$cmds.len().to_str()}")

    match Build.run!(graph) {
        Ok({}) => {
            Log.info!("publish finished")
            for eng in cfg.engines {
                Log.info!("  bundle-out/${eng.to_path_slug()}/")
            }
            Ok({})
        }
        Err(BuildFailed(msg)) => {
            Log.error!(msg)
            Err(Exit(1))
        }
    }
}
