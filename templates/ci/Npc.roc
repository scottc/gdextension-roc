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

Npc := {}.{
    physics_process! : F64 => {}
    physics_process! = |_delta| {
        CharacterBody3D.set_velocity!({
            x: CharacterBody3D.get_velocity!().x,
            y: CharacterBody3D.get_velocity!().y + PhysicsBody3D.get_gravity!().y.to_f32_wrap(),
            z: CharacterBody3D.get_velocity!().z,
        })
        _ = CharacterBody3D.move_and_slide!()
        {}
    }
}

movement_speed = 2.0
idle_speed = 0.0
jump_force = 50.0
