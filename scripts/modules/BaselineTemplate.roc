import Engine

BaselineTemplate := {}.{
    render : Engine -> Str
    render = |engine| {
        \\pub const abi = @import("glue-out/${engine.to_path_slug()}/roc_platform_abi.zig");
        \\pub const api = @import("glue-out/${engine.to_path_slug()}/zig_platform_abi_impl.zig");
        \\pub const baseline_gde_if = @import("glue-out/${engine.to_path_slug()}/gdextension_interface.zig");
        \\pub const gde_call = @import("glue-out/${engine.to_path_slug()}/gde_call.zig");
    }
}
