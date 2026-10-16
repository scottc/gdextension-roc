import StringHelper

ScannedTypeDefSlice : {
    comment : Str,
    typedef : Str,
    next : U64,
}

## A general purpose C header `.h` scanner
## To efficently find key needles in the source haystack
GDExtensionInterfaceScanner := {}.{
    needle_doc = "/**".to_utf8()
    needle_block_open = "/*".to_utf8()
    needle_block_close = "*/".to_utf8()
    needle_doc_end = "*/".to_utf8()
    needle_typedef = "typedef".to_utf8()
    needle_hash = "#".to_utf8()
    needle_line_comment = "//".to_utf8()
    needle_const = "const".to_utf8()

    # ---------------------------------------------------------------------------
    # Scanner
    # ---------------------------------------------------------------------------
    match_at : List(U8), U64, List(U8) -> Bool
    match_at = |bytes, i, needle_bytes| {
        StringHelper.bytes_eq_at(bytes, i, needle_bytes)
    }

    next_typedef_block : List(U8), U64 -> Try(ScannedTypeDefSlice, [Done])
    next_typedef_block = |bytes, start| {
        var $i = start
        len = bytes.len()
        while $i < len {
            match StringHelper.list_get(bytes, $i) {
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
                        match StringHelper.find_from(bytes, open, needle_doc_end) {
                            Err({}) => return Err(Done)
                            Ok(close) => {
                                after = close + 2
                                j = skip_ws_and_hash(bytes, after)
                                if match_at(bytes, j, needle_typedef) {
                                    match find_typedef_end(bytes, j) {
                                        Err({}) => return Err(Done)
                                        Ok(semi) => {
                                            return Ok({
                                                comment: StringHelper.slice_to_str(bytes, open, close),
                                                typedef: StringHelper.slice_to_str(bytes, j, semi).trim(),
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
                        match StringHelper.find_from(bytes, $i + 2, needle_block_close) {
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
                                    typedef: StringHelper.slice_to_str(bytes, $i, semi).trim(),
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
            match StringHelper.list_get(bytes, $i) {
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
            match StringHelper.list_get(bytes, $i) {
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
                    match StringHelper.list_get(bytes, i - 1) {
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
            match StringHelper.list_get(bytes, $j) {
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
                match StringHelper.list_get(bytes, $j) {
                    Ok(32.U8) | Ok(9.U8) | Ok(10.U8) | Ok(13.U8) => {
                        $j = $j + 1
                    }
                    _ => return $j
                }
            }
        }
        len
    }
}
