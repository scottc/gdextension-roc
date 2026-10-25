#!/usr/bin/env roc

#
# CI smoke: godot4.5 × x64musl only
#
#   roc run scripts/ci.roc
#   nix run github:lukewilliamboswell/roc-blueprint/0.5.0 -- run ci
#

app [main!] {
    pf: platform "https://github.com/scottc/roc-build/releases/download/nightly-2026-10-24-7a24d76/Fz3UXDv7ojxq6LHbEHUnSdn4mfynFnWAnLFGu9SXaF4c.tar.zst",
}

import pf.Build
import pf.Log
import pf.Mem

import BuildCmdHelper exposing [PhaseResult, ReplacePair]


# =============================================================================
# main!
# =============================================================================

main! : List(Str) => Try({}, [Exit(I32)])
main! = |args| {
    # Optional overrides, e.g.:
    #   --max-memory-gb=6 --max-parallel=2
    # Omit both → default_limits (safe on stock GHA).
    lim = parse_limits_or_default(args)

    Log.info!(
        "CI limits: max_memory=${lim.max_memory.to_str()} max_parallel=${lim.max_parallel.to_str()}",
    )

    graph = BuildCmdHelper.to_ci_build_graph(lim)

    match Build.run!(graph) {
        Ok({}) => {
            Log.info!("smoke ok")
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
            match U64.from_str(rest) {
                Ok(n) => Ok(n)
                Err(_err) => Err(NotFound)
            }
        }
        Err(_err) => Err(NotFound)
    }
}
