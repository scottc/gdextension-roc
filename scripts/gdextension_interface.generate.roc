#!/usr/bin/env roc

## gdextension_interface.h → Zig bindings
## Types first, then Interface struct + loadInterface.
##
## Usage:
##   roc run scripts/gdextension_interface.generate.roc -- --engine=godot
##   roc run scripts/gdextension_interface.generate.roc -- --engine=godot_4_5_1
##   roc run scripts/gdextension_interface.generate.roc -- --engine=redot

app [main!] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst"
}

import pf.Path
import pf.Stdout
import pf.Utc
import pf.OsStr
import pf.Cmd

needle_doc = "/**".to_utf8()
needle_block_open = "/*".to_utf8()
needle_block_close = "*/".to_utf8()
needle_doc_end = "*/".to_utf8()
needle_typedef = "typedef".to_utf8()
needle_hash = "#".to_utf8()
needle_line_comment = "//".to_utf8()
needle_const = "const".to_utf8()

Item : { comment: CommentInfo, typedef: TypeDefInfo }

Engine : [Godot, Godot4_5_1, Redot, Rex]

parse_engine : List(OsStr) -> Engine
parse_engine = |args| {
    for a in args {
        str = a.display()
        if str.starts_with("--engine=") {
            match str.replace_first("--engine=", "") {
                "godot" => return Godot
                "godot_4_5_1" => return Godot4_5_1
                "redot" => return Redot
                "rex" => return Rex
                _ => crash "invalid --engine= flag, must be: godot, godot_4_5_1, redot or rex."
            }
        }
    }

    Godot
}

engine_str : Engine -> Str
engine_str = |engine| {
    match engine {
        Godot => "godot"
        Godot4_5_1 => "godot_4_5_1"
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
        match next_typedef_block(bytes, $cursor) {
            Err(Done) => break
            Ok(scanned) => {
                $cursor = scanned.next
                $n = $n + 1

                comment = parse_comment_docs(scanned.comment)
                match parse_typedef(scanned.typedef) {
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
        val = strip_c_comments(v.value).trim()

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
        for d in split_lines(c.description) {
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
    join_with($lines, "\n")
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
    with_doc(c, join_with($parts, "\n"))
}

enum_variant_zig_name : Str, Str -> Str
enum_variant_zig_name = |full, common_prefix| {
    stripped =
        if !common_prefix.is_empty() and full.starts_with(common_prefix) {
            full.drop_prefix(common_prefix)
        } else {
            full
        }
    lower = lower_snake(stripped)
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
        match (list_get(ab, $i), list_get(bb, $i)) {
            (Ok(x), Ok(y)) if x == y => {
                $i = $i + 1
            }
            _ => break
        }
    }
    from_utf8_lossy(list_take_first(ab, $i))
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
        from_utf8_lossy(list_take_first(bytes, $last_us))
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
    with_doc(c, join_with($parts, "\n"))
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
        join_with(parameters.map(|p| zig_type(p.type_str)), ", ")
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
    fields_body = join_with($fields, "\n")
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
    body = join_with($inits, "\n")
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
    t = normalize_ws(raw).trim()
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
                if $end >= 5 and bytes_eq_at(bytes, $end - 5, needle_const) {
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
    base = from_utf8_lossy(base_bytes).trim()
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

# ---------------------------------------------------------------------------
# Scanner
# ---------------------------------------------------------------------------

ScannedTypeDefSlice : {
    comment : Str,
    typedef : Str,
    next : U64,
}

bytes_eq_at : List(U8), U64, List(U8) -> Bool
bytes_eq_at = |bytes, i, needle| {
    nlen = needle.len()
    if i + nlen > bytes.len() {
        Bool.False
    } else {
        var $k = 0.U64
        var $ok = Bool.True
        while $k < nlen {
            match (bytes.get(i + $k), needle.get($k)) {
                (Ok(a), Ok(b)) if a == b => {
                    $k = $k + 1
                }
                _ => {
                    $ok = Bool.False
                    break
                }
            }
        }
        $ok
    }
}

match_at : List(U8), U64, List(U8) -> Bool
match_at = |bytes, i, needle_bytes| {
    bytes_eq_at(bytes, i, needle_bytes)
}

find_from : List(U8), U64, List(U8) -> Try(U64, {})
find_from = |bytes, start, needle| {
    nlen = needle.len()
    len = bytes.len()
    if nlen == 0 {
        return Ok(start)
    }
    var $i = start
    while $i + nlen <= len {
        if bytes_eq_at(bytes, $i, needle) {
            return Ok($i)
        }
        $i = $i + 1
    }
    Err({})
}

find_str : Str, Str -> Try(U64, {})
find_str = |hay, needle| {
    find_from(hay.to_utf8(), 0, needle.to_utf8())
}

next_typedef_block : List(U8), U64 -> Try(ScannedTypeDefSlice, [Done])
next_typedef_block = |bytes, start| {
    var $i = start
    len = bytes.len()
    while $i < len {
        match list_get(bytes, $i) {
            Ok(35.U8) => {
                if is_hash_at(bytes, $i) {
                    $i = skip_line(bytes, $i)
                } else {
                    $i = $i + 1
                }
            }
            Ok(47.U8) => {
                if match_at(bytes, $i, needle_doc) {
                    open = $i + 3
                    match find_from(bytes, open, needle_doc_end) {
                        Err({}) => return Err(Done)
                        Ok(close) => {
                            after = close + 2
                            j = skip_ws_and_hash(bytes, after)
                            if match_at(bytes, j, needle_typedef) {
                                match find_typedef_end(bytes, j) {
                                    Err({}) => return Err(Done)
                                    Ok(semi) => {
                                        return Ok({
                                            comment: slice_to_str(bytes, open, close),
                                            typedef: slice_to_str(bytes, j, semi).trim(),
                                            next: semi + 1,
                                        })
                                    }
                                }
                            } else {
                                $i = after
                            }
                        }
                    }
                } else if match_at(bytes, $i, needle_block_open) {
                    match find_from(bytes, $i + 2, needle_block_close) {
                        Err({}) => return Err(Done)
                        Ok(close) => {
                            $i = close + 2
                        }
                    }
                } else if match_at(bytes, $i, needle_line_comment) {
                    $i = skip_line(bytes, $i)
                } else {
                    $i = $i + 1
                }
            }
            Ok(116.U8) => {
                if match_at(bytes, $i, needle_typedef) {
                    match find_typedef_end(bytes, $i) {
                        Err({}) => return Err(Done)
                        Ok(semi) => {
                            return Ok({
                                comment: "",
                                typedef: slice_to_str(bytes, $i, semi).trim(),
                                next: semi + 1,
                            })
                        }
                    }
                } else {
                    $i = $i + 1
                }
            }
            _ => {
                $i = $i + 1
            }
        }
    }
    Err(Done)
}

find_typedef_end : List(U8), U64 -> Try(U64, {})
find_typedef_end = |bytes, start| {
    var $i = start
    var $depth = 0.U64
    len = bytes.len()
    while $i < len {
        match list_get(bytes, $i) {
            Ok(123.U8) => {
                $depth = $depth + 1
                $i = $i + 1
            }
            Ok(125.U8) => {
                if $depth > 0 {
                    $depth = $depth - 1
                }
                $i = $i + 1
            }
            Ok(59.U8) if $depth == 0 => return Ok($i)
            Ok(34.U8) => {
                $i = skip_c_string(bytes, $i + 1)
            }
            _ => {
                $i = $i + 1
            }
        }
    }
    Err({})
}

skip_c_string = |bytes, start| {
    var $i = start
    len = bytes.len()
    while $i < len {
        match list_get(bytes, $i) {
            Ok(92.U8) => {
                if $i + 1 < len {
                    $i = $i + 2
                } else {
                    return len
                }
            }
            Ok(34.U8) => return $i + 1
            _ => {
                $i = $i + 1
            }
        }
    }
    len
}

is_hash_at : List(U8), U64 -> Bool
is_hash_at = |bytes, i| {
    at_line_start =
        i == 0
        or (
            i > 0
            and (
                match list_get(bytes, i - 1) {
                    Ok(10.U8) => Bool.True
                    Ok(13.U8) => Bool.True
                    _ => Bool.False
                }
            )
        )
    at_line_start and match_at(bytes, i, needle_hash)
}

skip_line : List(U8), U64 -> U64
skip_line = |bytes, i| {
    var $j = i
    len = bytes.len()
    while $j < len {
        match list_get(bytes, $j) {
            Ok(10.U8) => return $j + 1
            _ => {
                $j = $j + 1
            }
        }
    }
    len
}

skip_ws_and_hash : List(U8), U64 -> U64
skip_ws_and_hash = |bytes, i| {
    var $j = i
    len = bytes.len()
    while $j < len {
        if is_hash_at(bytes, $j) {
            $j = skip_line(bytes, $j)
        } else {
            match list_get(bytes, $j) {
                Ok(32.U8) | Ok(9.U8) | Ok(10.U8) | Ok(13.U8) => {
                    $j = $j + 1
                }
                _ => return $j
            }
        }
    }
    len
}

slice_to_str : List(U8), U64, U64 -> Str
slice_to_str = |bytes, start, end| {
    len = bytes.len()
    s = if start > len { len } else { start }
    e = if end > len { len } else { end }
    if s >= e {
        ""
    } else {
        var $out = []
        var $i = s
        while $i < e {
            match bytes.get($i) {
                Ok(b) => {
                    $out = $out.append(b)
                }
                Err(_) => break
            }
            $i = $i + 1
        }
        from_utf8_lossy($out)
    }
}

list_get : List(U8), U64 -> Try(U8, {})
list_get = |list, i| {
    match list.get(i) {
        Ok(b) => Ok(b)
        Err(_) => Err({})
    }
}

# ---------------------------------------------------------------------------
# Comment + typedef parsers
# ---------------------------------------------------------------------------

parse_comment_docs : Str -> CommentInfo
parse_comment_docs = |body| {
    lines = split_lines(body)
    var $name = ""
    var $since = ""
    var $return_doc = ""
    var $param_docs = []
    var $desc_parts = []
    for raw in lines {
        line = strip_star(raw).trim()
        if line.is_empty() {
            {}
        } else if line.starts_with("@name") {
            $name = tag_value(line, "@name")
        } else if line.starts_with("@since") {
            $since = tag_value(line, "@since")
        }
    }
    {
        name: $name,
        since: $since,
        description: join_lines($desc_parts),
        param_docs: $param_docs,
        return_doc: $return_doc,
    }
}

strip_star = |line| {
    t = line.trim()
    if t.starts_with("*") {
        t.drop_prefix("*").trim()
    } else {
        t
    }
}

tag_value = |line, tag| {
    line.drop_prefix(tag).trim()
}

parse_typedef : Str -> Try(TypeDefInfo, [ParseErr(Str)])
parse_typedef = |line| {
    t = line.trim()
    if !t.starts_with("typedef") {
        return Err(ParseErr("not a typedef"))
    }
    rest = t.drop_prefix("typedef").trim()
    if rest.starts_with("enum") {
        parse_enum_typedef(rest)
    } else if rest.starts_with("struct") {
        parse_struct_typedef(rest)
    } else if contains_str(rest, "(*") {
        parse_func_ptr_typedef(rest)
    } else {
        parse_alias_typedef(rest)
    }
}

parse_enum_typedef = |rest| {
    after_enum = rest.drop_prefix("enum").trim()
    match take_braced(after_enum) {
        Err(_) => Err(ParseErr("enum: missing { }"))
        Ok({ inner, after }) => {
            name = after.trim()
            if name.is_empty() {
                Err(ParseErr("enum: missing name"))
            } else {
                cleaned = strip_c_comments(inner)
                Ok(Enum({
                    name: name,
                    variants: parse_enum_variants(cleaned),
                }))
            }
        }
    }
}

strip_c_comments : Str -> Str
strip_c_comments = |s| {
    bytes = s.to_utf8()
    var $out = []
    var $i = 0.U64
    len = bytes.len()
    while $i < len {
        if $i + 1 < len and match_at(bytes, $i, needle_line_comment) {
            $i = $i + 2
            while $i < len {
                match list_get(bytes, $i) {
                    Ok(10.U8) => break
                    _ => {
                        $i = $i + 1
                    }
                }
            }
        } else if $i + 1 < len and match_at(bytes, $i, needle_block_open) {
            $i = $i + 2
            while $i + 1 < len {
                if match_at(bytes, $i, needle_block_close) {
                    $i = $i + 2
                    break
                }
                $i = $i + 1
            }
        } else {
            match list_get(bytes, $i) {
                Ok(b) => {
                    $out = $out.append(b)
                    $i = $i + 1
                }
                Err(_) => break
            }
        }
    }
    from_utf8_lossy($out)
}

parse_enum_variants : Str -> List(EnumVariant)
parse_enum_variants = |inner| {
    var $out = []
    var $auto = 0.I64
    for part in split_top_level(inner, ',') {
        p = part.trim()
        if p.is_empty() {
            {}
        } else {
            match split_first_char(p, '=') {
                Ok({ before, after }) => {
                    n = before.trim()
                    v = after.trim()
                    cleaned = strip_c_comments(v).trim()
                    $out = $out.append({ name: n, value: cleaned })
                    match I64.from_str(cleaned) {
                        Ok(num) => {
                            $auto = num + 1
                        }
                        Err(_) => {
                            $auto = $auto + 1
                        }
                    }
                }
                Err({}) => {
                    $out = $out.append({ name: p, value: $auto.to_str() })
                    $auto = $auto + 1
                }
            }
        }
    }
    $out
}

parse_struct_typedef : Str -> Try(TypeDefInfo, [ParseErr(Str)])
parse_struct_typedef = |rest| {
    after_struct = rest.drop_prefix("struct").trim()
    match take_braced(after_struct) {
        Err(_) => Err(ParseErr("struct: missing { }"))
        Ok({ inner, after }) => {
            name = after.trim()
            if name.is_empty() {
                Err(ParseErr("struct: missing name"))
            } else {
                cleaned = strip_c_comments(inner)
                Ok(Struct({ name: name, fields: parse_struct_fields(cleaned) }))
            }
        }
    }
}

parse_struct_fields : Str -> List(StructField)
parse_struct_fields = |inner| {
    var $out = []
    for part in split_top_level(inner, ';') {
        p = normalize_ws(part.trim())
        if p.is_empty() {
            {}
        } else {
            match parse_one_param(p) {
                Ok({ name, type_str }) if !name.is_empty() => {
                    $out = $out.append({ name: name, type_str: type_str })
                }
                _ => {}
            }
        }
    }
    $out
}

parse_func_ptr_typedef : Str -> Try(TypeDefInfo, [ParseErr(Str)])
parse_func_ptr_typedef = |rest| {
    bytes = rest.to_utf8()
    match find_from(bytes, 0, "(*".to_utf8()) {
        Err({}) => Err(ParseErr("missing (*"))
        Ok(idx) => {
            ret_raw = take_bytes(rest, idx).trim()
            after_star = drop_bytes(rest, idx + 2)
            match take_until_ascii(after_star, ')') {
                Err({}) => Err(ParseErr("missing ) after type name"))
                Ok(type_name) => {
                    after_name = drop_str_prefix(after_star, type_name).trim()
                    if !after_name.starts_with(")") {
                        return Err(ParseErr("expected ) after type name"))
                    }
                    after_rparen = after_name.drop_prefix(")").trim()
                    if !after_rparen.starts_with("(") {
                        return Err(ParseErr("expected ( args"))
                    }
                    args_body = after_rparen.drop_prefix("(").trim()
                    args_inner =
                        match take_until_ascii(args_body, ')') {
                            Ok(s) => s
                            Err({}) => args_body
                        }
                    Ok(FuncPtr({
                        name: type_name.trim(),
                        return_type: normalize_ws(ret_raw),
                        parameters: parse_param_list(args_inner),
                    }))
                }
            }
        }
    }
}

parse_alias_typedef : Str -> Try(TypeDefInfo, [ParseErr(Str)])
parse_alias_typedef = |rest| {
    s = normalize_ws(rest.trim())
    if s.is_empty() {
        return Err(ParseErr("empty alias"))
    }
    toks = normalize_alias_tokens(split_ws(s))
    match toks.last() {
        Err(_) => Err(ParseErr("bad alias"))
        Ok(last) => {
            if toks.len() < 2 {
                Err(ParseErr("alias needs type and name"))
            } else {
                { name, stars } = peel_leading_stars(last)
                if name.is_empty() {
                    Err(ParseErr("alias: name is only stars"))
                } else {
                    type_toks = toks.drop_last(1)
                    type_base = join_with(type_toks, " ")
                    type_str =
                        if stars == 0 {
                            type_base
                        } else {
                            "${type_base}${stars_str(stars)}"
                        }
                    Ok(Alias({ name: name, type_str: type_str }))
                }
            }
        }
    }
}

normalize_alias_tokens : List(Str) -> List(Str)
normalize_alias_tokens = |toks| {
    var $out = []
    for t in toks {
        if t == "*" {
            match $out.last() {
                Ok(prev) => {
                    $out = $out.drop_last(1).append("${prev}*")
                }
                Err(_) => {
                    $out = $out.append(t)
                }
            }
        } else if t.starts_with("*") and t != "*" {
            $out = $out.append(t)
        } else {
            $out = $out.append(t)
        }
    }
    $out
}

peel_leading_stars : Str -> { name : Str, stars : U64 }
peel_leading_stars = |tok| {
    bytes = tok.to_utf8()
    var $i = 0.U64
    var $stars = 0.U64
    len = bytes.len()
    while $i < len {
        match list_get(bytes, $i) {
            Ok(42.U8) => {
                $stars = $stars + 1
                $i = $i + 1
            }
            _ => break
        }
    }
    {
        name: slice_to_str(bytes, $i, bytes.len()),
        stars: $stars,
    }
}

stars_str : U64 -> Str
stars_str = |n| {
    match n {
        0 => ""
        1 => "*"
        2 => "**"
        3 => "***"
        _ => {
            var $out = []
            var $i = 0.U64
            while $i < n {
                $out = $out.append(42.U8)
                $i = $i + 1
            }
            from_utf8_lossy($out)
        }
    }
}

parse_param_list = |inner| {
    s = inner.trim()
    if s.is_empty() or s == "void" {
        []
    } else {
        var $out = []
        for part in split_args(s) {
            match parse_one_param(part) {
                Ok(p) => {
                    $out = $out.append(p)
                }
                Err(_) => {}
            }
        }
        $out
    }
}

parse_one_param = |raw| {
    p = raw.trim()
    if p.is_empty() {
        return Err(ParseErr("empty param"))
    }
    toks = split_ws(p)
    toks2 = merge_star_tokens(toks)
    match toks2.last() {
        Err(_) => Err(ParseErr("bad param"))
        Ok(last) => {
            if toks2.len() == 1 {
                Ok({ name: "", type_str: p })
            } else {
                { name, stars } = peel_leading_stars(last)
                if name.is_empty() {
                    Ok({ name: "", type_str: p })
                } else {
                    type_base = join_with(toks2.drop_last(1), " ")
                    type_str = if stars == 0 { type_base } else { "${type_base}${stars_str(stars)}" }
                    Ok({ name: name, type_str: type_str })
                }
            }
        }
    }
}

merge_star_tokens : List(Str) -> List(Str)
merge_star_tokens = |toks| {
    var $out = []
    for t in toks {
        if t == "*" {
            match $out.last() {
                Ok(prev) => {
                    $out = append_replace_last($out, "${prev}*")
                }
                Err(_) => {
                    $out = $out.append("*")
                }
            }
        } else {
            $out = $out.append(t)
        }
    }
    $out
}

append_replace_last : List(Str), Str -> List(Str)
append_replace_last = |list, new_last| {
    list.drop_last(1).append(new_last)
}

# ---------------------------------------------------------------------------
# String helpers
# ---------------------------------------------------------------------------

take_braced : Str -> Try({ inner : Str, after : Str }, [ParseErr(Str)])
take_braced = |s| {
    t = s.trim()
    if !t.starts_with("{") {
        return Err(ParseErr("expected {"))
    }
    bytes = t.to_utf8()
    var $i = 1.U64
    var $depth = 1.U64
    len = bytes.len()
    while $i < len {
        match list_get(bytes, $i) {
            Ok(123.U8) => {
                $depth = $depth + 1
                $i = $i + 1
            }
            Ok(125.U8) => {
                $depth = $depth - 1
                if $depth == 0 {
                    inner = slice_to_str(bytes, 1, $i)
                    after = slice_to_str(bytes, $i + 1, bytes.len())
                    return Ok({ inner: inner, after: after })
                }
                $i = $i + 1
            }
            _ => {
                $i = $i + 1
            }
        }
    }
    Err(ParseErr("unclosed {"))
}

split_top_level : Str, U8 -> List(Str)
split_top_level = |s, sep| {
    bytes = s.to_utf8()
    var $acc = []
    var $cur = []
    var $depth = 0.U64
    for b in bytes {
        if b == 40.U8 or b == 123.U8 or b == 91.U8 {
            $cur = $cur.append(b)
            $depth = $depth + 1
        } else if b == 41.U8 or b == 125.U8 or b == 93.U8 {
            $cur = $cur.append(b)
            if $depth > 0 {
                $depth = $depth - 1
            }
        } else if b == sep and $depth == 0 {
            part = from_utf8_lossy($cur).trim()
            if !part.is_empty() {
                $acc = $acc.append(part)
            }
            $cur = []
        } else {
            $cur = $cur.append(b)
        }
    }
    last = from_utf8_lossy($cur).trim()
    if !last.is_empty() {
        $acc = $acc.append(last)
    }
    $acc
}

split_first_char : Str, U8 -> Try({ before : Str, after : Str }, {})
split_first_char = |s, ch| {
    bytes = s.to_utf8()
    var $i = 0.U64
    for b in bytes {
        if b == ch {
            return Ok({
                before: slice_to_str(bytes, 0, $i),
                after: slice_to_str(bytes, $i + 1, bytes.len()),
            })
        }
        $i = $i + 1
    }
    Err({})
}

contains_str : Str, Str -> Bool
contains_str = |hay, needle| {
    match find_str(hay, needle) {
        Ok(_) => Bool.True
        Err(_) => Bool.False
    }
}

lower_snake : Str -> Str
lower_snake = |s| {
    bytes = s.to_utf8()
    var $out = []
    for b in bytes {
        if b >= 65.U8 and b <= 90.U8 {
            $out = $out.append(b + 32)
        } else {
            $out = $out.append(b)
        }
    }
    from_utf8_lossy($out)
}

split_lines : Str -> List(Str)
split_lines = |s| {
    bytes = s.to_utf8()
    var $acc = []
    var $cur = []
    for b in bytes {
        if b == 10.U8 {
            $acc = $acc.append(from_utf8_lossy($cur))
            $cur = []
        } else {
            $cur = $cur.append(b)
        }
    }
    $acc = $acc.append(from_utf8_lossy($cur))
    $acc
}

join_lines : List(Str) -> Str
join_lines = |lines| join_with(lines, "\n")

join_with : List(Str), Str -> Str
join_with = |parts, sep| {
    var $out = ""
    var $i = 0.U64
    for p in parts {
        if $i > 0 {
            $out = "${$out}${sep}${p}"
        } else {
            $out = p
        }
        $i = $i + 1
    }
    $out
}

from_utf8_lossy : List(U8) -> Str
from_utf8_lossy = |bytes| {
    match Str.from_utf8(bytes) {
        Ok(s) => s
        Err(_) => ""
    }
}

take_bytes : Str, U64 -> Str
take_bytes = |s, n| {
    b = s.to_utf8()
    end = if n < b.len() { n } else { b.len() }
    slice_to_str(b, 0, end)
}

drop_bytes : Str, U64 -> Str
drop_bytes = |s, n| {
    b = s.to_utf8()
    start = if n < b.len() { n } else { b.len() }
    slice_to_str(b, start, b.len())
}

take_until_ascii : Str, U8 -> Try(Str, {})
take_until_ascii = |s, ch| {
    bytes = s.to_utf8()
    var $i = 0.U64
    for b in bytes {
        if b == ch {
            return Ok(slice_to_str(bytes, 0, $i))
        }
        $i = $i + 1
    }
    Err({})
}

drop_str_prefix : Str, Str -> Str
drop_str_prefix = |s, prefix| {
    if s.starts_with(prefix) {
        drop_bytes(s, prefix.to_utf8().len())
    } else {
        s
    }
}

normalize_ws : Str -> Str
normalize_ws = |s| {
    bytes = s.to_utf8()
    var $out = []
    var $sp = Bool.False
    for b in bytes {
        if b == 32.U8 or b == 9.U8 or b == 10.U8 or b == 13.U8 {
            if !$sp {
                $out = $out.append(32.U8)
                $sp = Bool.True
            }
        } else {
            $out = $out.append(b)
            $sp = Bool.False
        }
    }
    from_utf8_lossy($out).trim()
}

split_ws : Str -> List(Str)
split_ws = |s| {
    bytes = s.to_utf8()
    var $acc = []
    var $cur = []
    for b in bytes {
        if b == 32.U8 or b == 9.U8 {
            if $cur.len() > 0 {
                $acc = $acc.append(from_utf8_lossy($cur))
                $cur = []
            }
        } else {
            $cur = $cur.append(b)
        }
    }
    if $cur.len() > 0 {
        $acc = $acc.append(from_utf8_lossy($cur))
    }
    $acc
}

split_args : Str -> List(Str)
split_args = |s| split_top_level(s, 44.U8)

list_take_first : List(U8), U64 -> List(U8)
list_take_first = |list, n| {
    var $out = []
    var $i = 0.U64
    for x in list {
        if $i >= n {
            break
        }
        $out = $out.append(x)
        $i = $i + 1
    }
    $out
}
