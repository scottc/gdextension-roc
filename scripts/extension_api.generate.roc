#!/usr/bin/env roc

## Generate Roc + Zig bindings from Godot's extension_api.json
##
## Usage:
##   roc run scripts/extension_api.generate.roc -- --engine=godot
##   roc run scripts/extension_api.generate.roc -- --engine=godot4.5
##   roc run scripts/extension_api.generate.roc -- --engine=godot4_5
##   roc run scripts/extension_api.generate.roc -- --engine=redot
##   roc run scripts/extension_api.generate.roc -- --engine=rex
##
## Path slug (dump-out/ / platform-out/ / host/glue-out/):
##   godot | godot4_5 | redot | rex

app [main!] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.23.0/GNN5tt2gKdX4dhawg4915C4YB193woHFdcCkz31fhGxv.tar.zst"
}

import pf.Path
import pf.Stdout
import pf.Utc
import pf.OsStr
import pf.Cmd

import modules/ModMap
import modules/CpuArchOS
import modules/ExtensionApiRenderer
import modules/ExtensionApi exposing [
    ExtensionApi,
    MethodDef,
    UtilityFunction,
    Singleton,
    BuiltinClass,
    ClassDef,
    SignalDef,
    EnumDef,
    PropertyDef,
]



## Split "a,b,c" on ',' (trim pieces; drop empties).
split_comma : Str -> List(Str)
split_comma = |s| {
    bytes = s.to_utf8()
    $acc : List(Str)
    var $acc = []
    $cur : List(U8)
    var $cur = []
    for b in bytes {
        if b == 44.U8 {
            # ','
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

parse_targets : List(OsStr) -> List(CpuArchOS)
parse_targets = |args| {
    for a in args {
        str = a.display()
        if str.starts_with("--targets=") {
            id = str.replace_first("--targets=", "")
            match id {
                "all" => return CpuArchOS.all
                "auto" => return CpuArchOS.auto
                raw => {
                    parts = split_comma(raw)
                    if parts.is_empty() {
                        return CpuArchOS.auto
                    } else {
                        crash "parse_targets implementation is incomplete, Fix me."
                        #return parts
                    }
                }
            }
        }
    }
    CpuArchOS.auto
}


Engine : [Godot, Godot4_5_1, Redot, Rex]

## Accept CI cli ids (godot4.5) and path slugs (godot4_5).
parse_engine : List(OsStr) -> Engine
parse_engine = |args| {
    for a in args {
        str = a.display()
        if str.starts_with("--engine=") {
            id = str.replace_first("--engine=", "")
            match id {
                "godot" => return Godot
                "godot4.5" => return Godot4_5_1
                "godot4.5.1" => return Godot4_5_1
                "godot4_5" => return Godot4_5_1
                "redot" => return Redot
                "rex" => return Rex
                _ => crash "invalid --engine= flag, must be: godot, godot4.5, godot4_5, redot or rex."
            }
        }
    }

    Godot
}

## Directory / path slug (not necessarily the CLI id).
engine_str : Engine -> Str
engine_str = |engine| {
    match engine {
        Godot => "godot"
        Godot4_5_1 => "godot4_5"
        Redot => "redot"
        Rex => "rex"
    }
}

# mkdir -p; args must be List(OsStr) on basic-cli 0.23
ensure_dir! : Path => Try({}, _)
ensure_dir! = |dir| {
    flag : OsStr
    flag = "-p"
    # Path → Str → OsStr (display/inspect depending on your Path API)
    dir_arg : OsStr
    dir_arg = dir.to_os_str() # Path stringifies in interpolation; annotate as OsStr
    {} = Cmd.exec!("mkdir", [flag, dir_arg])?
    Ok({})
}

ensure_platform_dirs! : Path => Try({}, _)
ensure_platform_dirs! = |roc_out| {
    ensure_dir!(roc_out)?
    ensure_dir!(Path.join(roc_out, "engine"))?
    ensure_dir!(Path.join(roc_out, "engine/math"))?
    ensure_dir!(Path.join(roc_out, "engine/builtin_classes"))?
    ensure_dir!(Path.join(roc_out, "engine/classes"))?
    ensure_dir!(Path.join(roc_out, "engine/singletons"))?
    Ok({})
}

main! : List(OsStr) => Try({}, _)
main! = |args| {

    user_args = args
    #     if List.is_empty(args) {
    #         []
    #     } else {
    #         List.drop_first(args, 1)
    #     }

    engine : Engine
    engine = parse_engine(user_args)
    eng = engine_str(engine)
    Stdout.line!("# Engine: ${eng}")?

    selected_targets : List(CpuArchOS)
    selected_targets = parse_targets(user_args)
    Stdout.line!("# Targets: ${Str.join_with(selected_targets.map(CpuArchOS.to_name), ",")}")?

    source : Path
    source = "dump-out/${eng}/extension_api.json"

    roc_out_path : Path
    roc_out_path = "platform-out/${eng}"

    glue_out_dir : Path
    glue_out_dir = "host/glue-out/${eng}"

    Stdout.line!("# extension_api.generate.roc")?

    # Create output trees (idempotent; safe if CI already mkdir'd the roots)
    ensure_platform_dirs!(roc_out_path)?
    ensure_dir!(glue_out_dir)?

    read_start = Utc.now!()
    json_contents = source.read_utf8!()?
    Stdout.line!("# Read: ${(Utc.now!() - read_start).to_str()}ns")?

    parse_start = Utc.now!()
    decoded : ExtensionApi
    decoded = Json.parse(json_contents)?
    Stdout.line!("# Parse: ${(Utc.now!() - parse_start).to_str()}ns")?
    Stdout.line!(
        \\# ${decoded.header.version_full_name}
        \\# builtins=${decoded.builtin_classes.len().to_str()} classes=${decoded.classes.len().to_str()}
    )?

    Path.join(roc_out_path, "GodotRoc.roc").write_utf8!(
        ExtensionApiRenderer.render_godot_roc_module()
    )?
    Path.join(roc_out_path, "Engine.roc").write_utf8!(
        ExtensionApiRenderer.render_engine_module()
    )?
    Path.join(roc_out_path, "Host.roc").write_utf8!(
        ExtensionApiRenderer.render_host_module(decoded)
    )?

    Path.join(roc_out_path, "EngineInfo.roc").write_utf8!(
        ExtensionApiRenderer.render_engine_info_module(decoded)
    )?
    #Path.join(roc_out_path, "Target.roc").write_utf8!(target(decoded))?

    Path.join(roc_out_path, "engine/GlobalConstants.roc").write_utf8!(
        ExtensionApiRenderer.render_global_constants_module(decoded)
    )?
    Path.join(roc_out_path, "engine/GlobalEnums.roc").write_utf8!(
        ExtensionApiRenderer.render_global_enums_module(decoded)
    )?
    Path.join(roc_out_path, "engine/BuiltinClassSizes.roc").write_utf8!(
        ExtensionApiRenderer.builtin_class_sizes_to_roc_source_str(decoded)
    )?
    Path.join(roc_out_path, "engine/BuiltinClassMemberOffsets.roc").write_utf8!(
        ExtensionApiRenderer.builtin_class_member_offsets_to_roc_source_str(decoded)
    )?
    Path.join(roc_out_path, "engine/NativeStructures.roc").write_utf8!(
        ExtensionApiRenderer.native_structures_to_roc_source_str(decoded)
    )?
    Path.join(roc_out_path, "engine/UtilityFunctions.roc").write_utf8!(
        ExtensionApiRenderer.utility_functions_to_roc_source_str(decoded)
    )?

    for name in ExtensionApiRenderer.math_type_names {
        Path.join(roc_out_path, "engine/math/${name}.roc")
            .write_utf8!(
                ExtensionApiRenderer.render_math_type_module(name)
            )?
    }

    for bic in decoded.builtin_classes {
        if ExtensionApiRenderer.is_struct_builtin(bic.name) {
            ops = ExtensionApiRenderer.render_method_module(bic)
            if ops != "" {
                Path.join(roc_out_path, "engine/math/${bic.name}Methods.roc")
                    .write_utf8!(ops)?
            }
        } else {
            mod_name = ExtensionApiRenderer.builtin_module_name(bic.name)
            Path.join(roc_out_path, "engine/builtin_classes/${mod_name}.roc").write_utf8!(
                ExtensionApiRenderer.render_builtin_class_module(bic)
            )?
        }
    }

    for cls in decoded.classes {
        mod_name = ModMap.class_module_name(cls.name)
        Path.join(roc_out_path, "engine/classes/${mod_name}.roc")
            .write_utf8!(ExtensionApiRenderer.render_class_module(cls))?
    }

    for s in decoded.singletons {
        mod_name = ModMap.singleton_module_name(s.name)
        Path.join(roc_out_path, "engine/singletons/${mod_name}.roc")
            .write_utf8!(ExtensionApiRenderer.render_singleton_module(decoded, s))?
    }

    Path.join(roc_out_path, "main.roc")
        .write_utf8!(ExtensionApiRenderer.render_platform_main(decoded, selected_targets, CpuArchOS.all))?

    Path.join(glue_out_dir, "zig_platform_abi_impl.zig")
        .write_utf8!(ExtensionApiRenderer.render_zig_platform_abi_impl(decoded))?

    Stdout.line!("# total after parse: ${(Utc.now!() - parse_start).to_str()}ns")?
    Ok({})
}
