### MyPlayerCharacter.roc - A player controlled character
# TODO: delete host import, use generated bespoke apis.
import pf.Host
import pf.Engine
#import pf.Target exposing [EngineKind]
import pf.GodotRoc

# bespoke apis
import pf.InputSingleton
import pf.Vector3
import pf.CharacterBody3D
import pf.PhysicsBody3D
import pf.Node3D

MyPlayerCharacter := {}.{
    physics_process! : F64 => {}
    physics_process! = |_delta| {

        Engine.print_warning!("MyPlayerCharacter.physics_process")

        gravity = PhysicsBody3D.get_gravity!().y.to_f32_wrap()
        lx = InputSingleton.get_axis!("left", "right").to_f32_wrap()
        lz = InputSingleton.get_axis!("forward", "back").to_f32_wrap()

        jump = InputSingleton.is_action_just_pressed!("jump", GodotRoc.false) == GodotRoc.true
        on_floor = CharacterBody3D.is_on_floor!() == GodotRoc.true

        velocity = CharacterBody3D.get_velocity!()

        vx_f : F32
        vx_f = (lx * movement_speed)
        vz_f : F32
        vz_f = (lz * movement_speed)

        vy_f : F32
        vy_f =
            velocity.y
            + gravity
            + (if jump and on_floor {
                jump_force.to_f32_wrap()
            } else {
                0.0.F32
            })

        CharacterBody3D.set_velocity!({
            x: vx_f,
            y: vy_f,
            z: vz_f,
        })

        _mas = CharacterBody3D.move_and_slide!()
        {}
    }
}

Character : {
    stats : Stats,
    level : U32,
    xp : U64,
    hp : F32,
    mana : F32,
    # inventory handle later
}

Stats : {
    strength : I32,
    dexterity : I32,
    intelligence : I32,
    vitality : I32,
}

derived_max_hp : Stats -> F32
derived_max_hp = |s| (s.vitality * 10).to_f32() + 50.0

derived_max_mana : Stats -> F32
derived_max_mana = |s| (s.intelligence * 5).to_f32() + 25.0

movement_speed = 2.0
idle_speed = 0.0
jump_force = 50.0
