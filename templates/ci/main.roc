app [ready!, process!, scene_init!, physics_process!] {
    pf: platform "[PLATFORM_GOES_HERE]",
}

# Top level multi-engine & multi-version platform
import pf.Engine
import pf.GodotRoc
import pf.Host

# Generated Per Engine:
import pf.EngineInfo
import pf.UtilityFunctions
import pf.Vector3
import pf.Vector3Methods
import pf.InputSingleton
import pf.EngineDebuggerSingleton

# This app..
import MyPlayerCharacter
import Npc

# ---------------------------------------------------------------------------
# App hooks
# ---------------------------------------------------------------------------

scene_init! : () => {}
scene_init! = || {
    Engine.print_warning!("Hello World!")
    Engine.print_warning!("Staticlly linked info:")
    #Engine.print_warning!("EngineInfo=${EngineInfo.version_full_name}")
    Engine.print_warning!("Dynamiclly linked info:")
    #Engine.print_warning!("engine_runtime_ok! = ${Engine.engine_runtime_ok!().to_str()}")
    #Engine.print_warning!("[smoke] current_engine! = ${Str.inspect(Engine.current_engine!())}")
    #Engine.print_warning!("[smoke] current_target! = ${Str.inspect(Engine.current_target!())}")

    # Roc API exists
    # but we want to trigger host stub not-implementated error...
    # just as a test...
    EngineDebuggerSingleton.script_debug!(0, 0, 0)

    player_class_id = Engine.register_class!("MyPlayerCharacter", "CharacterBody3D")
    Engine.print_warning!("Registered MyPlayerCharacter (id=${player_class_id.to_str()})")

    npc_class_id = Engine.register_class!("Npc", "CharacterBody3D")
    Engine.print_warning!("Registered Npc (id=${npc_class_id.to_str()})")
}

physics_process! : GodotRoc.ClassId, F64 => {}
physics_process! = |class_id, delta| {
    _ = match class_id {
        0 => MyPlayerCharacter.physics_process!(delta)
        1 => Npc.physics_process!(delta)
        _ => {}
    }
    {}
}

process! : GodotRoc.ClassId, F64 => {}
process! = |_class_id, _delta| {
    {}
}

unhandled_input! : () => {}
unhandled_input! = || {
    {}
}

ready! : () => {}
ready! = || {
    {}
}

# main! = |_args| {{}}
