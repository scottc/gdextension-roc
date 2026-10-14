#!/usr/bin/env roc

## gdextension_interface.h → Zig bindings
## Types first, then Interface struct + loadInterface.
##
## Usage:
##   roc run scripts/gdextension_interface.generate.roc -- --engine=godot
##   roc run scripts/gdextension_interface.generate.roc -- --engine=godot4.5
##   roc run scripts/gdextension_interface.generate.roc -- --engine=godot4_5
##   roc run scripts/gdextension_interface.generate.roc -- --engine=redot
##   roc run scripts/gdextension_interface.generate.roc -- --engine=rex
##
## Path slug (dump-out/ / host/glue-out/):
##   godot | godot4_5 | redot | rex

app [main!] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.23.0/GNN5tt2gKdX4dhawg4915C4YB193woHFdcCkz31fhGxv.tar.zst"
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
import modules/GDExtensionInterfaceScanner
import modules/GDExtensionInterfaceParser
import modules/GDExtensionInterface exposing [CommentInfo, TypeDefInfo, GDExtensionInterfaceItem]
import modules/GDExtensionInterfaceRenderer

# ---------------------------------------------------------------------------
# Entry
# ---------------------------------------------------------------------------

main! : List(OsStr) => Try({}, _)
main! = |args| {
    str_args = args.map(|a| a.display())
    engine : Engine
    engine = Args.parse_engine_flag(str_args)?

    Stdout.line!("# Engine: ${engine.to_name()}")?

    source : Path
    source = "dump-out/${engine.to_path_slug()}/gdextension_interface.h"

    glue_dir : Path
    glue_dir = "host/glue-out/${engine.to_path_slug()}"
    PathHelper.ensure_dir!(glue_dir)?

    out_path : Path
    out_path = Path.join(glue_dir, "gdextension_interface.zig")

    read_start = Utc.now!()
    c_contents = source.read_utf8!()?
    Stdout.line!("${Str.inspect(source)} Read time: ${(Utc.now!() - read_start).to_str()}ns")?

    bytes = c_contents.to_utf8()
    parse_start = Utc.now!()

    $items : List(GDExtensionInterfaceItem)
    var $items = []
    var $cursor = 0.U64
    var $n = 0.U64
    var $ok = 0.U64
    var $err = 0.U64
    var $guard = 0.U64

    while $guard < 50_000.U64 {
        $guard = $guard + 1
        match GDExtensionInterfaceScanner.next_typedef_block(bytes, $cursor) {
            Err(Done) => break
            Ok(scanned) => {
                $cursor = scanned.next
                $n = $n + 1

                comment = GDExtensionInterfaceParser.parse_comment_docs(scanned.comment)
                match GDExtensionInterfaceParser.parse_typedef(scanned.typedef) {
                    Ok(td) => {
                        $ok = $ok + 1
                        $items = $items.append({ comment: comment, typedef: td })
                    }
                    Err(e) => {
                        $err = $err + 1
                        Stdout.line!("post-parse n=${$n.to_str()} err ${Str.inspect(e)}")?
                        crash "[scripts/gdextension_interface.generate.roc] typedef parse failed"
                    }
                }
            }
        }
    }

    Stdout.line!("parse done n=${$n.to_str()} ok=${$ok.to_str()} err=${$err.to_str()} items=${$items.len().to_str()}")?
    Stdout.line!("parse time: ${(Utc.now!() - parse_start).to_str()}ns")?

    partition_start = Utc.now!()
    var $type_parts = []
    var $api_fns = []

    for item in $items {
        match item.typedef {
            FuncPtr({ name, return_type, parameters }) => {
                if !item.comment.name.is_empty() {
                    $api_fns = $api_fns.append({
                        api_name: item.comment.name,
                        typedef_name: name,
                        return_type: return_type,
                        parameters: parameters,
                        comment: item.comment,
                    })
                } else {
                    $type_parts = $type_parts.append(
                        GDExtensionInterfaceRenderer.render_func_ptr_type(name, return_type, parameters, item.comment),
                    )
                }
            }
            Alias({ name, type_str }) => {
                $type_parts = $type_parts.append(GDExtensionInterfaceRenderer.render_alias(name, type_str, item.comment))
            }
            Enum({ name, variants }) => {
                $type_parts = $type_parts.append(GDExtensionInterfaceRenderer.render_enum(name, variants, item.comment))
            }
            Struct({ name, fields }) => {
                $type_parts = $type_parts.append(GDExtensionInterfaceRenderer.render_struct(name, fields, item.comment))
            }
        }
    }

    Stdout.line!("types=${$type_parts.len().to_str()} api_fns=${$api_fns.len().to_str()}")?
    Stdout.line!("partition: ${(Utc.now!() - partition_start).to_str()}ns")?

    render_start = Utc.now!()
    render_result =
        \\//!
        \\//! GDExtension Interface
        \\//!
        \\//! generated by scripts/gdextension_interface.generate.roc
        \\//! generated from ${Str.inspect(source)}
        \\//! generated to ${Str.inspect(out_path)}
        \\//!
        \\
        \\${Str.join_with($type_parts, "")}
        \\
        \\${GDExtensionInterfaceRenderer.render_interface_struct($api_fns)}
        \\
        \\${GDExtensionInterfaceRenderer.render_fp_helper}
        \\
        \\${GDExtensionInterfaceRenderer.render_load_interface($api_fns)}
        \\

    Stdout.line!("render: ${(Utc.now!() - render_start).to_str()}ns")?

    write_start = Utc.now!()
    out_path.write_utf8!(render_result)?
    Stdout.line!("write: ${(Utc.now!() - write_start).to_str()}ns")?

    Ok({})
}
