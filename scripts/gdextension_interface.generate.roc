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

import modules/StringHelper
import modules/GDExtensionInterfaceScanner
import modules/GDExtensionInterfaceParser
import modules/GDExtensionInterface exposing []
import modules/GDExtensionInterfaceRenderer

Item : { comment: CommentInfo, typedef: TypeDefInfo }

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

ensure_dir! : Path => Try({}, _)
ensure_dir! = |dir| {
    flag : OsStr
    flag = "-p"
    dir_arg : OsStr
    dir_arg = dir.to_os_str()
    {} = Cmd.exec!("mkdir", [flag, dir_arg])?
    Ok({})
}

# ---------------------------------------------------------------------------
# Entry
# ---------------------------------------------------------------------------

main! : List(OsStr) => Try({}, _)
main! = |args| {
    user_args = args

    engine : Engine
    engine = parse_engine(user_args)
    eng = engine_str(engine)

    Stdout.line!("# Engine: ${eng}")?

    source : Path
    source = "dump-out/${eng}/gdextension_interface.h"

    glue_dir : Path
    glue_dir = "host/glue-out/${eng}"
    ensure_dir!(glue_dir)?

    out_path : Path
    out_path = Path.join(glue_dir, "gdextension_interface.zig")

    read_start = Utc.now!()
    c_contents = source.read_utf8!()?
    Stdout.line!("${Str.inspect(source)} Read time: ${(Utc.now!() - read_start).to_str()}ns")?

    bytes = c_contents.to_utf8()
    parse_start = Utc.now!()

    $items : List(Item)
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
                        render_func_ptr_type(name, return_type, parameters, item.comment),
                    )
                }
            }
            Alias({ name, type_str }) => {
                $type_parts = $type_parts.append(render_alias(name, type_str, item.comment))
            }
            Enum({ name, variants }) => {
                $type_parts = $type_parts.append(render_enum(name, variants, item.comment))
            }
            Struct({ name, fields }) => {
                $type_parts = $type_parts.append(render_struct(name, fields, item.comment))
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
        \\${render_interface_struct($api_fns)}
        \\
        \\${render_fp_helper}
        \\
        \\${render_load_interface($api_fns)}
        \\

    Stdout.line!("render: ${(Utc.now!() - render_start).to_str()}ns")?

    write_start = Utc.now!()
    out_path.write_utf8!(render_result)?
    Stdout.line!("write: ${(Utc.now!() - write_start).to_str()}ns")?

    Ok({})
}

# ---------------------------------------------------------------------------
# Parsed shapes
# ---------------------------------------------------------------------------

InterfaceFn : {
    api_name : Str,
    typedef_name : Str,
    return_type : Str,
    parameters : List(ParamInfo),
    comment : CommentInfo,
}

CommentInfo : {
    description : Str,
    name : Str,
    param_docs : List({ doc : Str, name : Str }),
    return_doc : Str,
    since : Str,
}

EnumVariant : { name : Str, value : Str }
StructField : { name : Str, type_str : Str }
ParamInfo : { name : Str, type_str : Str }

TypeDefInfo : [
    Alias({ name : Str, type_str : Str }),
    Enum({ name : Str, variants : List(EnumVariant) }),
    Struct({ name : Str, fields : List(StructField) }),
    FuncPtr({ name : Str, return_type : Str, parameters : List(ParamInfo) }),
]

# ---------------------------------------------------------------------------
# Enum value resolution (fixes FLAGS_DEFAULT = FLAG_NORMAL style aliases)
# ---------------------------------------------------------------------------

## Look up a previously resolved C enumerator name → integer.
find_enum_int : List(Str), List(I64), Str -> Try(I64, {})
find_enum_int = |names, ints, key| {
    var $i = 0.U64
    for n in names {
        if n == key {
            return match ints.get($i) {
                Ok(v) => Ok(v)
                Err(_) => Err({})
            }
        }
        $i = $i + 1
    }
    Err({})
}

## Lower every variant value to a decimal integer string.
## Handles:
##   NAME,                          → auto 0,1,2…
##   NAME = 4,                      → 4
##   NAME = OTHER_NAME,             → OTHER_NAME's integer
resolve_enum_variant_values : List(EnumVariant) -> List(EnumVariant)
resolve_enum_variant_values = |variants| {
    var $names = []
    var $ints = []
    var $out = []
    var $auto = 0.I64

    for v in variants {
        val = GDExtensionInterfaceParser.strip_c_comments(v.value).trim()

        n =
            if val.is_empty() {
                $auto
            } else {
                match I64.from_str(val) {
                    Ok(num) => num
                    Err(_) => {
                        # C identifier alias → resolve against earlier variants
                        match find_enum_int($names, $ints, val) {
                            Ok(num) => num
                            Err(_) => {
                                # Unknown expression — fall back to auto so Zig still compiles
                                $auto
                            }
                        }
                    }
                }
            }

        $names = $names.append(v.name)
        $ints = $ints.append(n)
        $out = $out.append({ name: v.name, value: n.to_str() })
        $auto = n + 1
    }

    $out
}

# ---------------------------------------------------------------------------
# Render: types
# ---------------------------------------------------------------------------

render_doc_block : CommentInfo -> Str
render_doc_block = |c| {
    var $lines = []
    if !c.name.is_empty() {
        $lines = $lines.append("/// @name ${c.name}")
    }
    if !c.since.is_empty() {
        $lines = $lines.append("/// @since ${c.since}")
    }
    if !c.description.is_empty() {
        for d in StringHelper.split_lines(c.description) {
            t = d.trim()
            if !t.is_empty() {
                $lines = $lines.append("/// ${t}")
            }
        }
    }
    for p in c.param_docs {
        $lines = $lines.append("/// @param ${p.name} ${p.doc}")
    }
    if !c.return_doc.is_empty() {
        $lines = $lines.append("/// @return ${c.return_doc}")
    }
    StringHelper.join_with($lines, "\n")
}

with_doc : CommentInfo, Str -> Str
with_doc = |c, body| {
    doc = render_doc_block(c)
    if doc.is_empty() {
        body
    } else {
        "${doc}\n${body}"
    }
}

render_alias : Str, Str, CommentInfo -> Str
render_alias = |name, type_str, c| {
    with_doc(c, "pub const ${name} = ${zig_type(type_str)};")
}

render_enum : Str, List(EnumVariant), CommentInfo -> Str
render_enum = |name, variants, c| {
    resolved = resolve_enum_variant_values(variants)
    c_names = resolved.map(|v| v.name)
    prefix = common_prefix_of(c_names)
    var $parts = ["pub const ${name} = enum(c_int) {"]
    for v in resolved {
        field = enum_variant_zig_name(v.name, prefix)
        $parts = $parts.append("    ${field} = ${v.value},")
    }
    $parts = $parts.append("};")
    with_doc(c, StringHelper.join_with($parts, "\n"))
}

enum_variant_zig_name : Str, Str -> Str
enum_variant_zig_name = |full, common_prefix| {
    stripped =
        if !common_prefix.is_empty() and full.starts_with(common_prefix) {
            full.drop_prefix(common_prefix)
        } else {
            full
        }
    lower = StringHelper.lower_snake(stripped)
    escape_zig_ident(lower)
}

common_prefix_of : List(Str) -> Str
common_prefix_of = |names| {
    if names.len() == 0 {
        ""
    } else {
        match names.first() {
            Err(_) => ""
            Ok(first) => {
                var $prefix = first
                for n in names {
                    $prefix = shared_prefix($prefix, n)
                }
                trim_prefix_to_underscore($prefix)
            }
        }
    }
}

shared_prefix : Str, Str -> Str
shared_prefix = |a, b| {
    ab = a.to_utf8()
    bb = b.to_utf8()
    var $i = 0.U64
    max =
        if ab.len() < bb.len() {
            ab.len()
        } else {
            bb.len()
        }
    while $i < max {
        match (StringHelper.list_get(ab, $i), StringHelper.list_get(bb, $i)) {
            (Ok(x), Ok(y)) if x == y => {
                $i = $i + 1
            }
            _ => break
        }
    }
    StringHelper.from_utf8_lossy(StringHelper.list_take_first(ab, $i))
}

trim_prefix_to_underscore : Str -> Str
trim_prefix_to_underscore = |p| {
    bytes = p.to_utf8()
    var $last_us = 0.U64
    var $i = 0.U64
    for b in bytes {
        if b == 95.U8 {
            $last_us = $i + 1
        }
        $i = $i + 1
    }
    if $last_us == 0 {
        ""
    } else {
        StringHelper.from_utf8_lossy(StringHelper.list_take_first(bytes, $last_us))
    }
}

escape_zig_ident : Str -> Str
escape_zig_ident = |name| {
    if is_zig_keyword(name) {
        "@\"${name}\""
    } else {
        name
    }
}

is_zig_keyword : Str -> Bool
is_zig_keyword = |n| {
    n == "error"
        or n == "and"
        or n == "or"
        or n == "try"
        or n == "catch"
        or n == "defer"
        or n == "errdefer"
        or n == "test"
        or n == "fn"
        or n == "type"
        or n == "var"
        or n == "const"
        or n == "struct"
        or n == "enum"
        or n == "union"
        or n == "opaque"
        or n == "export"
        or n == "extern"
        or n == "pub"
        or n == "return"
        or n == "break"
        or n == "continue"
        or n == "while"
        or n == "for"
        or n == "if"
        or n == "else"
        or n == "switch"
        or n == "orelse"
        or n == "async"
        or n == "await"
        or n == "suspend"
        or n == "resume"
}

render_struct : Str, List(StructField), CommentInfo -> Str
render_struct = |name, fields, c| {
    var $parts = ["pub const ${name} = extern struct {"]
    for f in fields {
        field_name = escape_zig_ident(f.name)
        $parts = $parts.append("    ${field_name}: ${zig_type(f.type_str)},")
    }
    $parts = $parts.append("};")
    with_doc(c, StringHelper.join_with($parts, "\n"))
}

render_func_ptr_type : Str, Str, List(ParamInfo), CommentInfo -> Str
render_func_ptr_type = |name, return_type, parameters, c| {
    with_doc(c, "pub const ${name} = ${fn_ptr_type_str(return_type, parameters)};")
}

fn_ptr_type_str : Str, List(ParamInfo) -> Str
fn_ptr_type_str = |return_type, parameters| {
    ret = zig_type(return_type)
    params_zig = format_fn_params(parameters)
    "*const fn (${params_zig}) callconv(.c) ${ret}"
}

format_fn_params : List(ParamInfo) -> Str
format_fn_params = |parameters| {
    if parameters.len() == 0 {
        ""
    } else {
        StringHelper.join_with(parameters.map(|p| zig_type(p.type_str)), ", ")
    }
}

# ---------------------------------------------------------------------------
# Render: Interface + loader
# ---------------------------------------------------------------------------

render_interface_struct : List(InterfaceFn) -> Str
render_interface_struct = |fns| {
    var $fields = []
    for f in fns {
        ty = fn_ptr_type_str(f.return_type, f.parameters)
        doc =
            if f.comment.since.is_empty() {
                ""
            } else {
                "    /// @since ${f.comment.since}\n"
            }
        $fields = $fields.append("${doc}    ${f.api_name}: ${ty},")
    }
    fields_body = StringHelper.join_with($fields, "\n")
    \\pub const Interface = struct {
    \\    // Raw function pointers – all non-optional after successful init
    \\${fields_body}
    \\};
}

render_fp_helper : Str
render_fp_helper =
    \\/// Returns proc address from get_proc_address lookup table function.
    \\fn pa(
    \\    get_proc_address: GDExtensionInterfaceGetProcAddress,
    \\    comptime name: [:0]const u8,
    \\    comptime T: type,
    \\) !T {
    \\    return @ptrCast(@alignCast(get_proc_address(name.ptr)));
    \\}

render_load_interface : List(InterfaceFn) -> Str
render_load_interface = |fns| {
    var $inits = []
    for f in fns {
        ty = fn_ptr_type_str(f.return_type, f.parameters)
        $inits = $inits.append(
            \\.${f.api_name} = try pa(gpa, "${f.api_name}", ${ty}),
        )
    }
    body = StringHelper.join_with($inits, "\n")
    \\pub fn loadInterface(get_proc_address: GDExtensionInterfaceGetProcAddress) !Interface {
    \\    const gpa = get_proc_address;
    \\    return .{
    \\${body}
    \\    };
    \\}
}

# ---------------------------------------------------------------------------
# C → Zig types
# ---------------------------------------------------------------------------

zig_type : Str -> Str
zig_type = |raw| {
    t = StringHelper.normalize_ws(raw).trim()
    if t.is_empty() or t == "void" {
        "void"
    } else {
        { base, stars, is_const } = split_c_type(t)
        mapped = map_base_type(base)
        apply_pointers(mapped, stars, is_const)
    }
}

split_c_type : Str -> { base : Str, stars : U64, is_const : Bool }
split_c_type = |t| {
    s = t.trim()
    var $is_const = Bool.False
    var $rest = s
    if $rest.starts_with("const ") {
        $is_const = Bool.True
        $rest = $rest.drop_prefix("const ").trim()
    }
    bytes = $rest.to_utf8()
    var $end = bytes.len()
    var $stars = 0.U64
    var $guard = 0.U64
    while $guard < 16 and $end > 0 {
        $guard = $guard + 1
        match bytes.get($end - 1) {
            Ok(32.U8) | Ok(9.U8) => {
                $end = $end - 1
            }
            Ok(42.U8) => {
                $stars = $stars + 1
                $end = $end - 1
            }
            _ => {
                if $end >= 5 and StringHelper.bytes_eq_at(bytes, $end - 5, GDExtensionInterfaceScanner.needle_const) {
                    $is_const = Bool.True
                    $end = $end - 5
                } else {
                    break
                }
            }
        }
    }
    base_bytes = {
        var $out = []
        var $i = 0.U64
        while $i < $end {
            match bytes.get($i) {
                Ok(b) => {
                    $out = $out.append(b)
                }
                Err(_) => break
            }
            $i = $i + 1
        }
        $out
    }
    base = StringHelper.from_utf8_lossy(base_bytes).trim()
    { base: base, stars: $stars, is_const: $is_const }
}

map_base_type : Str -> Str
map_base_type = |b| {
    match b {
        "void" => "anyopaque"
        "char" => "u8"
        "signed char" => "i8"
        "unsigned char" => "u8"
        "wchar_t" => "c_ushort"
        "short" | "short int" | "signed short" | "signed short int" => "c_short"
        "unsigned short" | "unsigned short int" => "c_ushort"
        "int" | "signed int" | "signed" => "c_int"
        "unsigned int" | "unsigned" => "c_uint"
        "long" | "long int" | "signed long" => "c_long"
        "unsigned long" | "unsigned long int" => "c_ulong"
        "long long" | "long long int" => "c_longlong"
        "unsigned long long" | "unsigned long long int" => "c_ulonglong"
        "float" => "f32"
        "double" => "f64"
        "size_t" => "usize"
        "ptrdiff_t" => "isize"
        "int8_t" => "i8"
        "uint8_t" => "u8"
        "int16_t" => "i16"
        "uint16_t" => "u16"
        "int32_t" => "i32"
        "uint32_t" => "u32"
        "int64_t" => "i64"
        "uint64_t" => "u64"
        "char16_t" => "u16"
        "char32_t" => "u32"
        _ => b
    }
}

apply_pointers : Str, U64, Bool -> Str
apply_pointers = |base, stars, is_const| {
    if stars == 0 {
        base
    } else {
        var $t = base
        var $i = 0.U64
        while $i < stars {
            if $i == stars - 1 and (base == "anyopaque" or base == "u8") {
                if base == "u8" and is_const {
                    $t = "[*:0]const u8"
                } else if base == "u8" {
                    $t = "[*c]u8"
                } else if is_const {
                    $t = "?*const anyopaque"
                } else {
                    $t = "?*anyopaque"
                }
            } else if is_const and $i == stars - 1 {
                $t = "[*c]const ${$t}"
            } else {
                $t = "[*c]${$t}"
            }
            $i = $i + 1
        }
        $t
    }
}
