Version : { major: U32, minor: U32 }

Engine := [
    Godot(Version),
    Redot(Version),
    Rex(Version),
].{

    to_path_slug : Engine -> Str
    to_path_slug = |engine| {
        match engine {
            Godot(v) => "godot${v.major.to_str()}_${v.minor.to_str()}"
            Redot(v) => "redot${v.major.to_str()}_${v.minor.to_str()}"
            Rex(v) => "rex${v.major.to_str()}_${v.minor.to_str()}"
        }
    }

    to_name : Engine -> Str
    to_name = |engine| {
        match engine {
            Godot(v) => "godot${v.major.to_str()}.${v.minor.to_str()}"
            Redot(v) => "redot${v.major.to_str()}.${v.minor.to_str()}"
            Rex(v) => "rex${v.major.to_str()}.${v.minor.to_str()}"
        }
    }

    from_name : Str -> Engine
    from_name = |str| {
        # TODO: parse version number
        if str.starts_with("godot") {
            _ver_str = str.replace_first("godot", "")
            Godot({ major: 4, minor: 5 })
        } else if str.starts_with("redot") {
            _ver_str = str.replace_first("redot", "")
            Redot({ major: 26, minor: 2 })
        } else if str.starts_with("rex") {
            _ver_str = str.replace_first("rex", "")
            Rex({ major: 0, minor: 0 })
        } else {
            crash \\EngineParseError("name engine name; must match one of the following formats: godot4.5 | redot26.2 | rex0.0. But got ${str}")
        }
    }
}
