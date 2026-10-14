StringHelper := {}.{

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
        match StringHelper.find_str(hay, needle) {
            Ok(_) => Bool.True
            Err(_) => Bool.False
        }
    }

    find_str : Str, Str -> Try(U64, {})
    find_str = |hay, needle| {
        find_from(hay.to_utf8(), 0, needle.to_utf8())
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
}
