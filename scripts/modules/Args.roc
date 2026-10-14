## Args.roc
import Engine
import CpuArchOS
import StringHelper
import Host exposing [Optimize]

Args := {}.{
    ## --engine=godot4.5
    parse_engine_flag : List(Str) -> Try(Engine, [MissingRequiredEngineFlag(Str)])
    parse_engine_flag = |args| {
        for str in args {
            if str.starts_with("--engine=") {
                id = str.replace_first("--engine=", "")
                return Ok(Engine.from_name(id))
            }
        }
        Err(MissingRequiredEngineFlag("Missing: --engine="))
    }

    ## --baseline=godot4.5
    parse_baseline_flag : List(Str) -> Try(Engine, [MissingRequiredBaselineFlag(Str)])
    parse_baseline_flag = |args| {
        for str in args {
            if str.starts_with("--baseline=") {
                id = str.replace_first("--baseline=", "")
                return Ok(Engine.from_name(id))
            }
        }
        Err(MissingRequiredBaselineFlag("Missing: --baseline="))
    }

    ## --engines=godot4.5,redot26.2,rex0.0
    parse_engines_flag : List(Str) -> Try(List(Engine), [MissingRequiredEnginesFlag(Str)])
    parse_engines_flag = |args| {
        for str in args {
            if str.starts_with("--engines=") {
                ids_str = str.replace_first("--engines=", "")
                ids = StringHelper.split_comma(ids_str)

                var $engines = List.with_capacity(ids.len())
                for id in ids {
                    $engines = $engines.append(Engine.from_name(id))
                }
                return Ok($engines)
            }
        }
        Err(MissingRequiredEnginesFlag("Missing: --engines="))
    }

    ## Takes raw string args, parses flag: --targets=wasm32,x64musl
    parse_targets_flag : List(Str) -> Try(List(CpuArchOS), [MissingRequiredTargetsFlag(Str)])
    parse_targets_flag = |args| {
        targets_key = "--targets="
        for str in args {
            if str.starts_with(targets_key) {
                id = str.replace_first(targets_key, "")
                match id {
                    "all" => return Ok(CpuArchOS.all)
                    "auto" => return Ok(CpuArchOS.auto)
                    raw => {
                        parts = StringHelper.split_comma(raw)
                        if parts.is_empty() {
                            return Ok(CpuArchOS.auto) # default
                        } else {
                            return Ok(parts.map(CpuArchOS.from_name))
                        }
                    }
                }
            }
        }
        Err(MissingRequiredTargetsFlag("Missing: --targets="))
    }

    parse_optimize_flag : List(Str) -> Optimize
    parse_optimize_flag = |args| {
        match flag_value(args, "-Doptimize=") {
            Some("Debug") => Debug
            Some("ReleaseFast") => ReleaseFast
            Some("ReleaseSafe") => ReleaseSafe
            Some("ReleaseSmall") => ReleaseSmall
            _ => ReleaseFast
        }
    }

    parse_tag_flag : List(Str) -> [AutoTag, Tag(Str)]
    parse_tag_flag = |args| {
        match flag_value(args, "--tag=") {
            Some(t) => Tag(t)
            None => AutoTag
        }
    }



    PublishOpts : {
        tag : [AutoTag, Tag(Str)],
    }
}

flag_value : List(Str), Str -> [None, Some(Str)]
flag_value = |args, prefix| {
    for a in args {
        if a.starts_with(prefix) {
            return Some(a.drop_prefix(prefix))
        }
    }
    None
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
