Engine := [
    Godot({ version: GodotVersion, tag: VersionPointer }),
    Redot({ version: RedotVersion, tag: VersionPointer }),
    Rex({ version: RexVersion, tag: VersionPointer }),
]

VersionPointer : [LatestStable, LatestNightly, ExplicitVersion]

GodotVersion : [
    Godot4_8,
    Godot4_7,
    Godot4_6,
    Godot4_5,
    Godot4_4,
    Godot4_3,
    Godot4_2,
    Godot4_1,
]

RedotVersion : [
    Redot26_2,
    Redot26_1,
    # ...etc
]

RexVersion : [
    Rex0_0,
]
