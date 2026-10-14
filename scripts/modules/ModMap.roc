## We need to rename some things, to avoid collisions.
ModMap := {}.{
    class_module_name : Str -> Str
    class_module_name = |name| {
        match name {
            "Crypto" => "GodotCrypto"
            "Range" => "GodotRange"
            "Engine" => "GodotEngine"
            other => other
        }
    }

    singleton_module_name : Str -> Str
    singleton_module_name = |name| "${name}Singleton"
}
