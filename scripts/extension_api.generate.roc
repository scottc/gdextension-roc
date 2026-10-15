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
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst"
}

import pf.Path
import pf.Stdout
import pf.Utc
import pf.OsStr
import pf.Cmd

import effects/PathHelper

import modules/Args
import modules/Engine
import modules/StringHelper
import modules/ModMap
import modules/CpuArchOS
import modules/ExtensionApiRenderer
import modules/ExtensionApi exposing [
    #ExtensionApi,
    MethodDef,
    UtilityFunction,
    Singleton,
    BuiltinClass,
    ClassDef,
    SignalDef,
    EnumDef,
    PropertyDef,
]

main! : List(OsStr) => Try({}, _)
main! = |args| {

    str_args = args.map(|a| a.display())

    engine : Engine
    engine = Args.parse_engine_flag_or_godot4_5(str_args)
    Stdout.line!("# Engine: ${Str.inspect(engine)}")?

    selected_targets : List(CpuArchOS)
    selected_targets = Args.parse_targets_flag_or_auto(str_args)

    Stdout.line!("# Targets: ${Str.join_with(selected_targets.map(CpuArchOS.to_name), ",")}")?

    source : Path
    source = "dump-out/${engine.to_path_slug()}/extension_api.json"

    roc_out_path : Path
    roc_out_path = "platform-out/${engine.to_path_slug()}"

    glue_out_dir : Path
    glue_out_dir = "host/glue-out/${engine.to_path_slug()}"

    Stdout.line!("# extension_api.generate.roc")?

    # Create output trees (idempotent; safe if CI already mkdir'd the roots)
    PathHelper.ensure_platform_dirs!(roc_out_path)?
    PathHelper.ensure_dir!(glue_out_dir)?

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
