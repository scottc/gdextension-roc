## My Project — sample + light CI smoke tests
app [ready!, process!, scene_init!, physics_process!] {
    pf: platform "[PLATFORM_GOES_HERE]",
}

# Top level multi-engine & multi-version platform
import pf.Engine
import pf.Target
import pf.GodotRoc
import pf.Host

# Generated Per Engine:
import pf.EngineInfo
import pf.UtilityFunctions
import pf.Vector3
import pf.Vector3Methods
import pf.InputSingleton
# TODO: Can the game dev alias & re-export these?
# EngineInfo = import pf.godot4_7.EngineInfo
# EngineInfo = import pf.redot23.EngineInfo

# This app..
import MyPlayerCharacter
import Npc

# ---------------------------------------------------------------------------
# Smoke (flat — fewer effect branches for the Roc compiler)
# ---------------------------------------------------------------------------

run_smoke_tests! : () => {}
run_smoke_tests! = || {
    Engine.print_warning!("========== godot-roc smoke tests ==========")

    # The static engine versions that the platform was compiled against
    # And thus are avaliable to use.
    # Engine.print_warning!("[smoke] platform_api = ${Str.inspect(EngineInfo.platform_api)}")
    # Engine exclusive APIs, will be gatekept behind a tag union...??

    # The actual runtime engine version that is running.
    Engine.print_warning!("[smoke] target_engine! = ${Str.inspect(Engine.target_engine!())}")

    # TODO:
    # Returns the current runtime engine
    # from the avalible engines APIs baked into this .tar.
    # if you need different versions, either compile platform from source with the engines.
    # or submit a GH issue.
    # _result = match Engine.target_engine!() {
    #     Target.Godot4_7(godot47) => "gd: ${Str.inspect(godot47.do_advanced_shadows())}"
    #     Target.Redot23(redot23) => "rd: ${Str.inspect(redot23.do_3d_terrain())}"
    #     _ => crash "Runtime engine mis-match, use one of the other supported engines!"
    # }

    # host enforcement of static version(s) == runtime version.
    ok = Engine.engine_runtime_ok!()
    Engine.print_warning!("[smoke] engine_runtime_ok! = ${ok.to_str()}")

    # ----- utilities (callUtility) -----
    m = UtilityFunctions.maxf!(3.0, 7.0)
    Engine.print_warning!("[smoke] maxf(3,7) = ${m.to_str()}")

    n = UtilityFunctions.minf!(3.0, 7.0)
    Engine.print_warning!("[smoke] minf(3,7) = ${n.to_str()}")

    c = UtilityFunctions.clampf!(15.0, 0.0, 10.0)
    Engine.print_warning!("[smoke] clampf(15,0,10) = ${c.to_str()}")

    a = UtilityFunctions.absf!(-4.5)
    Engine.print_warning!("[smoke] absf(-4.5) = ${a.to_str()}")

    s0 = UtilityFunctions.sin!(0.0)
    Engine.print_warning!("[smoke] sin(0) = ${s0.to_str()}")

    c0 = UtilityFunctions.cos!(0.0)
    Engine.print_warning!("[smoke] cos(0) = ${c0.to_str()}")

    lr = UtilityFunctions.lerpf!(0.0, 10.0, 0.5)
    Engine.print_warning!("[smoke] lerpf(0,10,0.5) = ${lr.to_str()}")

    deg = UtilityFunctions.deg_to_rad!(180.0)
    Engine.print_warning!("[smoke] deg_to_rad(180) = ${deg.to_str()}")

    mi = UtilityFunctions.maxi!(2, 9)
    Engine.print_warning!("[smoke] maxi(2,9) = ${mi.to_str()}")

    ai = UtilityFunctions.absi!(-3)
    Engine.print_warning!("[smoke] absi(-3) = ${ai.to_str()}")

    eq = UtilityFunctions.is_equal_approx!(1.0, 1.0)
    Engine.print_warning!("[smoke] is_equal_approx(1,1) = ${Str.inspect(eq)}")

    pow2 = UtilityFunctions.pow!(2.0, 3.0)
    Engine.print_warning!("[smoke] pow(2,3) = ${pow2.to_str()}")

    sq = UtilityFunctions.sqrt!(9.0)
    Engine.print_warning!("[smoke] sqrt(9) = ${sq.to_str()}")

    # ----- math layout (Roc-only) -----
    v : Vector3
    v = { x: 3.0, y: 0.0, z: 4.0 }
    Engine.print_warning!("[smoke] Vector3 layout = ${v.x.to_str()}, ${v.y.to_str()}, ${v.z.to_str()}")

    # ----- builtin methods (callBuiltin via Host) -----
    # Replace hashes with names from platform/gen/Host.roc
    v_len = Vector3Methods.length!(v)
    Engine.print_warning!("[smoke] Vector3.length(3,0,4) = ${v_len.to_str()}")
    # expect ~5

    v2 : Vector3
    v2 = { x: 1.0, y: 0.0, z: 0.0 }
    # dot hash: rg vector3_dot platform/gen/Host.roc
    v_dot = Vector3Methods.dot!(v2, v2)
    Engine.print_warning!("[smoke] Vector3.dot((1,0,0),(1,0,0)) = ${v_dot.to_str()}")
    # expect ~1

    # ----- singleton getters -----
    input_ptr = Host.get_singleton_input!()
    Engine.print_warning!("[smoke] get_singleton_input ptr = ${input_ptr.to_str()}")
    # expect non-zero when engine is up

    engine_ptr = Host.get_singleton_engine!()
    Engine.print_warning!("[smoke] get_singleton_engine ptr = ${engine_ptr.to_str()}")

    # ----- engine façade (StringName path in host.zig) -----
    pressed = InputSingleton.is_action_pressed!("ui_accept", GodotRoc.false)
    Engine.print_warning!("[smoke] is_action_pressed(ui_accept) = ${Str.inspect(pressed)}")

    jp = InputSingleton.is_action_just_pressed!("ui_accept", GodotRoc.true)
    Engine.print_warning!("[smoke] just_pressed(ui_accept) = ${Str.inspect(jp)}")

    jv = InputSingleton.is_action_just_released!("ui_accept", GodotRoc.true)
    Engine.print_warning!("[smoke] just_released(ui_accept) = ${Str.inspect(jv)}")

    axis = InputSingleton.get_axis!("ui_left", "ui_right")
    Engine.print_warning!("[smoke] get_axis(ui_left,ui_right) = ${axis.to_str()}")

    # Character body — after regen, prefer generated names if current-instance wired:
    # floor = CharacterBody3D.is_on_floor!()  # only if that module uses g_godot_roc_current

    Engine.print_warning!("========== smoke: finished (check values above) ==========")
    {}
}

# TODO:
# do_gd : Target.Godot4_7, Str => {}
# do_gd = |gd, str| {
#     gd.do_advanced_shadows!()
#     {}
# }

# do_rd : Target.Redot23, Str => {}
# do_rd = |rd, str| {
#     gd.do_3d_terrain!()
#     {}
# }

# ---------------------------------------------------------------------------
# App hooks
# ---------------------------------------------------------------------------

scene_init! : () => {}
scene_init! = || {
    Engine.print_warning!("Hello World!")

    player_class_id = Engine.register_class!("MyPlayerCharacter", "CharacterBody3D")
    Engine.print_warning!("Registered MyPlayerCharacter id= ${player_class_id.to_str()}")

    npc_class_id = Engine.register_class!("Npc", "CharacterBody3D")
    Engine.print_warning!("Registered Npc id= ${npc_class_id.to_str()}")

    run_smoke_tests!()
}

physics_process! : GodotRoc.ClassId, F64 => {}
physics_process! = |class_id, delta| {
    # physics smoke test...
    # pos = Engine.get_position!()
    # Engine.print_warning!("[smoke] get_position = ...")

    Engine.print_warning!("physics_process! class_id: ${class_id.to_str()}, delta: ${delta.to_str()}")

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

main! = |_args| {{}}
