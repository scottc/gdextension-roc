Version : { major: U32, minor: U32 }

Engine := [
    Godot(Version),
    Redot(Version),
    Blazium(Version),
].{
    expect Engine.Godot({ major: 4, minor: 3 }).to_path_slug() == "godot4_3"
    expect Engine.Redot({ major: 26, minor: 3 }).to_path_slug() == "redot26_3"
    expect Engine.Blazium({ major: 0, minor: 6 }).to_path_slug() == "blazium0_6"
    to_path_slug : Engine -> Str
    to_path_slug = |engine| {
        match engine {
            Godot(v) => "godot${v.major.to_str()}_${v.minor.to_str()}"
            Redot(v) => "redot${v.major.to_str()}_${v.minor.to_str()}"
            Blazium(v) => "blazium${v.major.to_str()}_${v.minor.to_str()}"
        }
    }

    expect Engine.Godot({ major: 4, minor: 3 }).to_name() == "godot4.3"
    expect Engine.Redot({ major: 26, minor: 3 }).to_name() == "redot26.3"
    expect Engine.Blazium({ major: 0, minor: 6 }).to_name() == "blazium0.6"
    to_name : Engine -> Str
    to_name = |engine| {
        match engine {
            Godot(v) => "godot${v.major.to_str()}.${v.minor.to_str()}"
            Redot(v) => "redot${v.major.to_str()}.${v.minor.to_str()}"
            Blazium(v) => "blazium${v.major.to_str()}.${v.minor.to_str()}"
        }
    }

    expect Engine.Godot({ major: 4, minor: 7 }).to_cli_name() == "godot4.7"
    expect Engine.Godot({ major: 4, minor: 5 }).to_cli_name() == "godot4.3"
    expect Engine.Redot({ major: 26, minor: 3 }).to_cli_name() == "redot"
    expect Engine.Blazium({ major: 0, minor: 6 }).to_cli_name() == "blazium"
    to_cli_name : Engine -> Str
    to_cli_name = |engine| {
        match engine {
            # Hmmm... how do we detect if godot should be:
            # "latest implict: 'godot'" or "explict version: 'godot4.3'"
            Godot(v) => "godot${v.major.to_str()}.${v.minor.to_str()}"
            Redot(_version) => "redot"
            Blazium(_version) => "blazium"
        }
    }

    expect match Engine.from_name("godot4.5") {
        Ok(Godot({ major: 4, minor: 5 })) => True
        _ => False
    }
    expect match Engine.from_name("redot26.3") {
        Ok(Redot({ major: 26, minor: 3 })) => True
        _ => False
    }
    expect match Engine.from_name("blazium0.6") {
        Ok(Blazium({ major: 0, minor: 6 })) => True
        _ => False
    }
    expect match Engine.from_name("ERROR") {
        Err(_) => True
        _ => False
    }
    from_name : Str -> Try(Engine, _)
    from_name = |str| {
        # TODO: parse version number
        if str.starts_with("godot") {
            ver_str = str.replace_first("godot", "").split_on(".")
            Ok(Godot({
                major: U32.from_str(ver_str.first()?)?,
                minor: U32.from_str(ver_str.last()?)?,
            }))
        } else if str.starts_with("redot") {
            ver_str = str.replace_first("redot", "").split_on(".")
            Ok(Redot({
                major: U32.from_str(ver_str.first()?)?,
                minor: U32.from_str(ver_str.last()?)?,
            }))
        } else if str.starts_with("blazium") {
            ver_str = str.replace_first("blazium", "").split_on(".")
            Ok(Blazium({
                major: U32.from_str(ver_str.first()?)?,
                minor: U32.from_str(ver_str.last()?)?,
            }))
        } else {
            Err(EngineParseError("name engine name; must match one of the following formats: godot4.5 | redot26.3 | blazium0.6. But got ${str}"))
        }
    }
}
