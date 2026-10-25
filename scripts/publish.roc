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
    pf: platform "https://github.com/scottc/roc-build/releases/download/nightly-2026-10-24-7a24d76/Fz3UXDv7ojxq6LHbEHUnSdn4mfynFnWAnLFGu9SXaF4c.tar.zst",
}

import pf.Build
import pf.Log
import pf.Mem

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
        baseline: Args.parse_baseline_flag_or_godot4_3(args),
        engines: Args.parse_engines_flag_or_empty(args),
        hosts: Args.parse_targets_flag_or_auto(args),
        optimize: Args.parse_optimize_flag_or_release_fast(args),
        publish: { tag: Args.parse_tag_flag_or_autotag(args) },
        limits: parse_limits_or_default(args),
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
    #graph : BuildGraph
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

## Parse --max-memory-gb=N and --max-parallel=N; fall back to default_limits.
parse_limits_or_default : List(Str) -> BuildCmdHelper.Limits
parse_limits_or_default = |args| {
    mem_gb = flag_u64(args, "--max-memory-gb=")
    par = flag_u64(args, "--max-parallel=")
    match (mem_gb, par) {
        (Ok(m), Ok(p)) => BuildCmdHelper.limits(Mem.gb(m), p)
        (Ok(m), Err(_)) => BuildCmdHelper.limits(Mem.gb(m), BuildCmdHelper.default_limits.max_parallel)
        (Err(_), Ok(p)) => BuildCmdHelper.limits(BuildCmdHelper.default_limits.max_memory, p)
        (Err(_), Err(_)) => BuildCmdHelper.default_limits
    }
}

flag_u64 : List(Str), Str -> Try(U64, [NotFound])
flag_u64 = |args, prefix| {
    match List.find_first(args, |a| Str.starts_with(a, prefix)) {
        Ok(flag) => {
            rest = Str.drop_prefix(flag, prefix)
            when Str.to_u64(rest) {
                Ok(n) => Ok(n)
                Err(_err) => Err(NotFound)
            }
        }
        Err(_err) => Err(NotFound)
    }
}
