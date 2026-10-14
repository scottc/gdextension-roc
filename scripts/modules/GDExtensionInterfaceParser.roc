import GDExtensionInterfaceScanner
import GDExtensionInterface exposing [CommentInfo, TypeDefInfo, StructField, EnumVariant]
import StringHelper

GDExtensionInterfaceParser := {

}.{
    # ---------------------------------------------------------------------------
    # Comment + typedef parsers
    # ---------------------------------------------------------------------------

    parse_comment_docs : Str -> CommentInfo
    parse_comment_docs = |body| {
        lines = StringHelper.split_lines(body)
        var $name = ""
        var $since = ""
        var $return_doc = ""
        var $param_docs = []
        var $desc_parts = []
        for raw in lines {
            line = StringHelper.strip_star(raw).trim()
            if line.is_empty() {
                {}
            } else if line.starts_with("@name") {
                $name = StringHelper.tag_value(line, "@name")
            } else if line.starts_with("@since") {
                $since = StringHelper.tag_value(line, "@since")
            }
        }
        {
            name: $name,
            since: $since,
            description: StringHelper.join_lines($desc_parts),
            param_docs: $param_docs,
            return_doc: $return_doc,
        }
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
        } else if StringHelper.contains_str(rest, "(*") {
            parse_func_ptr_typedef(rest)
        } else {
            parse_alias_typedef(rest)
        }
    }

    parse_enum_typedef = |rest| {
        after_enum = rest.drop_prefix("enum").trim()
        match StringHelper.take_braced(after_enum) {
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
            if $i + 1 < len and GDExtensionInterfaceScanner.match_at(bytes, $i, GDExtensionInterfaceScanner.needle_line_comment) {
                $i = $i + 2
                while $i < len {
                    match StringHelper.list_get(bytes, $i) {
                        Ok(10.U8) => break
                        _ => {
                            $i = $i + 1
                        }
                    }
                }
            } else if $i + 1 < len and GDExtensionInterfaceScanner.match_at(bytes, $i, GDExtensionInterfaceScanner.needle_block_open) {
                $i = $i + 2
                while $i + 1 < len {
                    if GDExtensionInterfaceScanner.match_at(bytes, $i, GDExtensionInterfaceScanner.needle_block_close) {
                        $i = $i + 2
                        break
                    }
                    $i = $i + 1
                }
            } else {
                match StringHelper.list_get(bytes, $i) {
                    Ok(b) => {
                        $out = $out.append(b)
                        $i = $i + 1
                    }
                    Err(_) => break
                }
            }
        }
        StringHelper.from_utf8_lossy($out)
    }

    parse_enum_variants : Str -> List(EnumVariant)
    parse_enum_variants = |inner| {
        var $out = []
        var $auto = 0.I64
        for part in StringHelper.split_top_level(inner, ',') {
            p = part.trim()
            if p.is_empty() {
                {}
            } else {
                match StringHelper.split_first_char(p, '=') {
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
        match StringHelper.take_braced(after_struct) {
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
        for part in StringHelper.split_top_level(inner, ';') {
            p = StringHelper.normalize_ws(part.trim())
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
        match StringHelper.find_from(bytes, 0, "(*".to_utf8()) {
            Err({}) => Err(ParseErr("missing (*"))
            Ok(idx) => {
                ret_raw = StringHelper.take_bytes(rest, idx).trim()
                after_star = StringHelper.drop_bytes(rest, idx + 2)
                match StringHelper.take_until_ascii(after_star, ')') {
                    Err({}) => Err(ParseErr("missing ) after type name"))
                    Ok(type_name) => {
                        after_name = StringHelper.drop_str_prefix(after_star, type_name).trim()
                        if !after_name.starts_with(")") {
                            return Err(ParseErr("expected ) after type name"))
                        }
                        after_rparen = after_name.drop_prefix(")").trim()
                        if !after_rparen.starts_with("(") {
                            return Err(ParseErr("expected ( args"))
                        }
                        args_body = after_rparen.drop_prefix("(").trim()
                        args_inner =
                            match StringHelper.take_until_ascii(args_body, ')') {
                                Ok(s) => s
                                Err({}) => args_body
                            }
                        Ok(FuncPtr({
                            name: type_name.trim(),
                            return_type: StringHelper.normalize_ws(ret_raw),
                            parameters: parse_param_list(args_inner),
                        }))
                    }
                }
            }
        }
    }

    parse_alias_typedef : Str -> Try(TypeDefInfo, [ParseErr(Str)])
    parse_alias_typedef = |rest| {
        s = StringHelper.normalize_ws(rest.trim())
        if s.is_empty() {
            return Err(ParseErr("empty alias"))
        }
        toks = normalize_alias_tokens(StringHelper.split_ws(s))
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
                        type_base = StringHelper.join_with(type_toks, " ")
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
            match StringHelper.list_get(bytes, $i) {
                Ok(42.U8) => {
                    $stars = $stars + 1
                    $i = $i + 1
                }
                _ => break
            }
        }
        {
            name: StringHelper.slice_to_str(bytes, $i, bytes.len()),
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
                StringHelper.from_utf8_lossy($out)
            }
        }
    }

    parse_param_list = |inner| {
        s = inner.trim()
        if s.is_empty() or s == "void" {
            []
        } else {
            var $out = []
            for part in StringHelper.split_args(s) {
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
        toks = StringHelper.split_ws(p)
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
                        type_base = StringHelper.join_with(toks2.drop_last(1), " ")
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

}
