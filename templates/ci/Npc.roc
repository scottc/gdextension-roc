### MyPlayerCharacter.roc - A player controlled character
# TODO: delete host import, use generated bespoke apis.
import pf.Host
import pf.Engine
import pf.GodotRoc

# bespoke apis
import pf.InputSingleton
import pf.Vector3
import pf.CharacterBody3D
import pf.PhysicsBody3D
import pf.Node3D

movement_speed = 2.0
idle_speed = 0.0
jump_force = 50.0

physics_process! : F64 => {}
physics_process! = |_delta| {
    gravity = PhysicsBody3D.get_gravity!().y.to_f32_wrap()
    velocity = CharacterBody3D.get_velocity!()
    CharacterBody3D.set_velocity!({
        x: velocity.x,
        y: velocity.y + (-gravity),
        z: velocity.z,
    })
    _mas = CharacterBody3D.move_and_slide!()
    {}
}

# Default app modules must have a main! function.
main! = |_args| {{}}
