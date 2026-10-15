## Args.roc
import Engine
import CpuArchOS
import StringHelper
import Host exposing [Optimize]

Args := {}.{
    ## --engine=godot4.3
    parse_engine_flag_or_godot4_3 : List(Str) -> Engine
    parse_engine_flag_or_godot4_3 = |args| {
        e : Engine
        e = match flag_value(args, "--engine=") {
            Some(bl) =>
                match Engine.from_name(bl) {
                    Ok(eg) => eg
                    _ => Godot({ major: 4, minor: 3 })
                }
            None => Godot({ major: 4, minor: 3 })
        }
        e
    }

    ## --baseline=godot4.3
    parse_baseline_flag_or_godot4_3 : List(Str) -> Engine
    parse_baseline_flag_or_godot4_3 = |args| {
        e : Engine
        e = match flag_value(args, "--baseline=") {
            Some(bl) =>
                match Engine.from_name(bl) {
                    Ok(eg) => eg
                    _ => Godot({ major: 4, minor: 3 })
                }
            None => Godot({ major: 4, minor: 3 })
        }
        e
    }

    ## --engines=godot4.5,redot26.2,rex0.0
    parse_engines_flag_or_empty : List(Str) -> List(Engine)
    parse_engines_flag_or_empty = |args| {
        match flag_value(args, "--engines=") {
            Some(v) => {
                ids = StringHelper.split_comma(v)
                var $engines = List.with_capacity(ids.len())
                for id in ids {
                    match Engine.from_name(id) {
                        Ok(eg) => {
                            $engines = $engines.append(eg)
                        }
                        _ => {}
                    }
                }
                $engines
            }
            None => []
        }
    }

    ## Takes raw string args, parses flag: --targets=wasm32,x64musl
    parse_targets_flag_or_auto : List(Str) -> List(CpuArchOS)
    parse_targets_flag_or_auto = |args| {
        match flag_value(args, "--targets=") {
            Some(raw) => {
                parts = StringHelper.split_comma(raw)
                if parts.is_empty() {
                    CpuArchOS.auto
                } else {
                    parts.map(CpuArchOS.from_name)
                }
            }
            None => CpuArchOS.auto
        }
    }

    parse_optimize_flag_or_release_fast : List(Str) -> Optimize
    parse_optimize_flag_or_release_fast = |args| {
        match flag_value(args, "-Doptimize=") {
            Some("Debug") => Debug
            Some("ReleaseFast") => ReleaseFast
            Some("ReleaseSafe") => ReleaseSafe
            Some("ReleaseSmall") => ReleaseSmall
            _ => ReleaseFast
        }
    }

    parse_tag_flag_or_autotag : List(Str) -> [AutoTag, Tag(Str)]
    parse_tag_flag_or_autotag = |args| {
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
