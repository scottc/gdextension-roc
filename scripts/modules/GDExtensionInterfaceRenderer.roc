import GDExtensionInterfaceParser
import GDExtensionInterfaceScanner
import GDExtensionInterface exposing [CommentInfo, EnumVariant, ParamInfo, StructField, InterfaceFn]
import StringHelper

GDExtensionInterfaceRenderer := {

}.{

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

}
