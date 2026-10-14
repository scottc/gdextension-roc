///! godot-roc platform host
///! Effectful functions for godot-4.5.1+ GDExtension ABI.
///!
///! Keep wasm32-emscripten compatible; use is_wasm_target where needed.
const std = @import("std");
const builtin = @import("builtin");

// WORKAROUND: zig 0.16.0 windows compiler bug.
pub const std_options: std.Options = .{
    .allow_stack_tracing = false,
};

const abi = @import("baseline.zig").abi;
const api = @import("baseline.zig").api;
const baseline_gde_if = @import("baseline.zig").baseline_gde_if;
const gde_call = @import("baseline.zig").gde_call;

fn ctx() gde_call.Ctx {
    return .{ .iface = &g_engine_interface, .library = g_engine_library };
}

// Roc app entrypoints
extern fn godot_roc_scene_init() callconv(.c) void;
extern fn godot_roc_ready() callconv(.c) void;
extern fn godot_roc_process(class_id: u32, delta: f64) callconv(.c) void;
extern fn godot_roc_physics_process(class_id: u32, delta: f64) callconv(.c) void;

const is_wasm_target = builtin.cpu.arch == .wasm32;
const is_native_target = !is_wasm_target;

// ---------------------------------------------------------------------------
// Engine / Roc globals
// ---------------------------------------------------------------------------

var g_engine_library: baseline_gde_if.GDExtensionClassLibraryPtr = null;
var g_engine_interface: baseline_gde_if.Interface = undefined;
var g_engine_runtime_version: baseline_gde_if.GDExtensionGodotVersion = undefined;
var g_engine_runtime_version2: baseline_gde_if.GDExtensionGodotVersion2 = undefined;

var g_roc_host: ?*abi.RocHost = null;
var g_roc_host_env: ?HostEnv = null;
var g_roc_host_storage: abi.RocHost = undefined;
var g_roc_memory: [16 * 1024 * 1024]u8 = undefined;
var g_roc_fba_state: std.heap.FixedBufferAllocator = undefined;

const MAX_CLASSES = 32;
const MAX_NAME_LEN = 63;
const USER_SLOT_COUNT: usize = 16;
var g_godot_roc_classes: [MAX_CLASSES]GodotRocClassInfo = undefined;
var g_godot_roc_class_count: usize = 0;
var g_next_instance_id: u64 = 1;
var g_godot_roc_current_instance: ?*GodotRocObjectInstance = null;

// wherever you used to set the current instance:
// api.g_godot_roc_current = @ptrCast(instance_ptr); // ?*GodotRocObjectInstance → ?*anyopaque

// Cached singletons (optional; gde_call.getSingleton also works each time)
var g_input: baseline_gde_if.GDExtensionObjectPtr = null;
var g_engine_singleton: baseline_gde_if.GDExtensionObjectPtr = null;

// ---------------------------------------------------------------------------
// godot_roc_init
// ---------------------------------------------------------------------------

export fn godot_roc_init(
    p_get_proc_address: baseline_gde_if.GDExtensionInterfaceGetProcAddress,
    p_library: baseline_gde_if.GDExtensionClassLibraryPtr,
    r_initialization: *baseline_gde_if.GDExtensionInitialization,
) callconv(.c) baseline_gde_if.GDExtensionBool {
    g_engine_library = p_library;
    g_engine_interface = baseline_gde_if.loadInterface(p_get_proc_address) catch return 0;
    gde_call.setCtx(.{ .iface = &g_engine_interface, .library = g_engine_library });

    g_engine_interface.get_godot_version(&g_engine_runtime_version);
    if (g_engine_runtime_version.major != 4 and g_engine_runtime_version.major != 1 and g_engine_runtime_version.major != 0) {
        var ver_buf: [256]u8 = undefined;
        const ver_slice = cStrToSlice(g_engine_runtime_version.string, 128);
        const ver_msg = bufPrintC(
            &ver_buf,
            "This version of godot-roc was compiled for godot 4.7.2, but got: {s}.",
            .{ver_slice},
        ) catch "godot-roc: version mismatch (string truncated).";
        g_engine_interface.print_error(ver_msg.ptr, "godot_roc_init", "host.zig", @src().line, 1);
    }

    g_engine_interface.get_godot_version2(&g_engine_runtime_version2);

    r_initialization.* = .{
        .minimum_initialization_level = .initialization_scene,
        .userdata = null,
        .initialize = &initialize,
        .deinitialize = &deinitialize,
    };
    return 1;
}

fn cStrToSlice(p: [*:0]const u8, max: usize) []const u8 {
    var i: usize = 0;
    while (i < max and p[i] != 0) : (i += 1) {}
    return p[0..i];
}

fn bufPrintC(buf: []u8, comptime fmt: []const u8, args: anytype) ![:0]const u8 {
    if (buf.len == 0) return error.NoSpaceLeft;
    const written = try std.fmt.bufPrint(buf[0 .. buf.len - 1], fmt, args);
    buf[written.len] = 0;
    return buf[0..written.len :0];
}

// ---------------------------------------------------------------------------
// Roc runtime exports
// ---------------------------------------------------------------------------

export fn roc_alloc(length: usize, alignment: usize) callconv(.c) ?*anyopaque {
    return abi.DefaultAllocators.rocAlloc(g_roc_host.?, length, alignment);
}

export fn roc_dealloc(ptr: *anyopaque, alignment: usize) callconv(.c) void {
    abi.DefaultAllocators.rocDealloc(g_roc_host.?, ptr, alignment);
}

export fn roc_realloc(ptr: *anyopaque, new_length: usize, alignment: usize) callconv(.c) ?*anyopaque {
    return abi.DefaultAllocators.rocRealloc(g_roc_host.?, ptr, new_length, alignment);
}

export fn roc_dbg(bytes: [*]const u8, len: usize) callconv(.c) void {
    abi.DefaultHandlers.rocDbg(g_roc_host.?, bytes, len);
}

export fn roc_expect_failed(bytes: [*]const u8, len: usize) callconv(.c) void {
    abi.DefaultHandlers.rocExpectFailed(g_roc_host.?, bytes, len);
}

export fn roc_crashed(bytes: [*]const u8, len: usize) callconv(.c) void {
    if (is_native_target) {
        std.debug.print("[roc_crashed] {s}\n", .{bytes[0..len]});
    }
    abi.DefaultHandlers.rocCrashed(g_roc_host.?, bytes, len);
}

// ---------------------------------------------------------------------------
// Façade: print / register_class
// ---------------------------------------------------------------------------

export fn godot_roc_print_error(roc_str: abi.RocStr) callconv(.c) void {
    const roc_host = g_roc_host.?;
    var owned = roc_str;
    defer owned.decref(roc_host);

    var buf: [64]u8 = undefined;
    const s = owned.asSlice();
    if (s.len >= buf.len) return;
    @memcpy(buf[0..s.len], s);
    buf[s.len] = 0;
    printError("godot_roc_print_error(\"{s}\")\n", .{buf[0..s.len :0]});
}

export fn godot_roc_print_warning(roc_str: abi.RocStr) callconv(.c) void {
    const roc_host = g_roc_host.?;
    var owned = roc_str;
    defer owned.decref(roc_host);

    var buf: [64]u8 = undefined;
    const s = owned.asSlice();
    if (s.len >= buf.len) return;
    @memcpy(buf[0..s.len], s);
    buf[s.len] = 0;
    printWarn("godot_roc_print_warning(\"{s}\")\n", .{buf[0..s.len :0]});
}

fn registerClassFromRoc(class_slice: []const u8, parent_slice: []const u8) u32 {
    if (g_godot_roc_class_count >= MAX_CLASSES) {
        printError("register_class: MAX_CLASSES={d}\n", .{MAX_CLASSES});
        return 0;
    }
    if (class_slice.len > MAX_NAME_LEN or parent_slice.len > MAX_NAME_LEN) {
        printError("register_class: name longer than MAX_NAME_LEN={d}\n", .{MAX_NAME_LEN});
        return 0;
    }

    const i = g_godot_roc_class_count;
    const info = &g_godot_roc_classes[i];

    @memcpy(info.name[0..class_slice.len], class_slice);
    info.name[class_slice.len] = 0;
    info.name_len = @intCast(class_slice.len);

    @memcpy(info.parent[0..parent_slice.len], parent_slice);
    info.parent[parent_slice.len] = 0;
    info.parent_len = @intCast(parent_slice.len);

    info.class_id = @intCast(i);
    g_godot_roc_class_count += 1;

    registerClass(info);
    return info.class_id;
}

export fn godot_roc_register_class(
    class_name: abi.RocStr,
    parent_class_name: abi.RocStr,
) callconv(.c) u32 {
    const roc_host = g_roc_host.?;
    var class_owned = class_name;
    defer class_owned.decref(roc_host);
    var parent_owned = parent_class_name;
    defer parent_owned.decref(roc_host);

    const class_slice = class_owned.asSlice();
    const parent_slice = parent_owned.asSlice();

    printWarn("[host.zig] godot_roc_register_class({s}, {s})\n", .{ class_slice, parent_slice });
    const id = registerClassFromRoc(class_slice, parent_slice);
    printWarn("godot_roc_register_class returning id={d}\n", .{id});
    return id;
}

export fn godot_roc_current_engine() callconv(.c) u8 {
    // 0 = Godot4_7 for this package
    return 0;
}

export fn godot_roc_current_target() callconv(.c) u8 {
    // 0 = Godot4_7 for this package
    return 0;
}

export fn godot_roc_engine_runtime_ok() callconv(.c) u8 {
    // Optional: compare get_godot_version major/minor to 4/7
    return 1;
}

export fn godot_roc_instance_id() callconv(.c) u64 {
    const self = requireCurrentInstance() orelse return 0;
    return self.instance_id;
}

export fn godot_roc_instance_class_id() callconv(.c) u32 {
    const self = requireCurrentInstance() orelse return 0;
    return self.class_id;
}

export fn godot_roc_user_slot_count() callconv(.c) u64 {
    return USER_SLOT_COUNT;
}

export fn godot_roc_user_slot_get(index: u64) callconv(.c) u64 {
    const self = requireCurrentInstance() orelse return 0;
    if (index >= USER_SLOT_COUNT) return 0;
    return self.user_slots[@intCast(index)];
}

export fn godot_roc_user_slot_set(index: u64, value: u64) callconv(.c) void {
    const self = requireCurrentInstance() orelse return;
    if (index >= USER_SLOT_COUNT) {
        printError("user_slot_set: index {d} >= {d}\n", .{ index, USER_SLOT_COUNT });
        return;
    }
    self.user_slots[@intCast(index)] = value;
}

/// Bit-cast helpers so apps do not hand-roll endian tricks in Roc for floats.
export fn godot_roc_user_slot_get_f32(index: u64) callconv(.c) f32 {
    const bits = godot_roc_user_slot_get(index);
    return @bitCast(@as(u32, @truncate(bits)));
}

export fn godot_roc_user_slot_set_f32(index: u64, value: f32) callconv(.c) void {
    const bits: u32 = @bitCast(value);
    godot_roc_user_slot_set(index, @as(u64, bits));
}

// ---------------------------------------------------------------------------
// Façade: CharacterBody3D / Input via gde_call
// ---------------------------------------------------------------------------

export fn godot_roc_set_velocity(v: api.Vector3) callconv(.c) void {
    const obj = requireCurrentObject() orelse return;
    var gv = v;
    const args = [_]baseline_gde_if.GDExtensionConstTypePtr{@ptrCast(&gv)};
    _ = gde_call.callInstance(
        ctx(),
        "CharacterBody3D",
        "set_velocity",
        api.hashes.CharacterBody3D_set_velocity,
        obj,
        &args,
        null,
    );
}

export fn godot_roc_get_velocity() callconv(.c) api.Vector3 {
    const obj = requireCurrentObject() orelse {
        return .{ .x = 0, .y = 0, .z = 0 };
    };
    var gv = api.Vector3{ .x = 0, .y = 0, .z = 0 };
    _ = gde_call.callInstance(
        ctx(),
        "CharacterBody3D",
        "get_velocity",
        api.hashes.CharacterBody3D_get_velocity,
        obj,
        null,
        @ptrCast(&gv),
    );
    return gv;
}

export fn godot_roc_move_and_slide() callconv(.c) void {
    const obj = requireCurrentObject() orelse return;
    var hit: baseline_gde_if.GDExtensionBool = 0;
    _ = gde_call.callInstance(
        ctx(),
        "CharacterBody3D",
        "move_and_slide",
        api.hashes.CharacterBody3D_move_and_slide,
        obj,
        null,
        @ptrCast(&hit),
    );
}

export fn godot_roc_is_on_floor() callconv(.c) baseline_gde_if.GDExtensionBool {
    const obj = requireCurrentObject() orelse return 0;
    var ret: baseline_gde_if.GDExtensionBool = 0;
    _ = gde_call.callInstance(
        ctx(),
        "CharacterBody3D",
        "is_on_floor",
        api.hashes.CharacterBody3D_is_on_floor,
        obj,
        null,
        @ptrCast(&ret),
    );
    return ret;
}

export fn godot_roc_get_gravity() callconv(.c) api.Vector3 {
    const obj = requireCurrentObject() orelse {
        return .{ .x = 0, .y = -9.8, .z = 0 };
    };
    var g = std.mem.zeroes(api.Vector3);
    // API hash is on PhysicsBody3D in extension_api for this method
    _ = gde_call.callInstance(
        ctx(),
        "CharacterBody3D",
        "get_gravity",
        api.hashes.PhysicsBody3D_get_gravity,
        obj,
        null,
        @ptrCast(&g),
    );
    return g;
}

fn ensureInput() ?*anyopaque {
    if (g_input == null) {
        g_input = gde_call.getSingleton(ctx(), "Input");
    }
    return g_input;
}

fn inputIsActionPressed(action_z: [:0]const u8) u8 {
    const input = ensureInput() orelse return 0;
    var action = gde_call.makeStringName(ctx(), action_z);
    defer gde_call.destroyStringName(ctx(), &action);

    var out: u8 = 0;
    const args = [_]baseline_gde_if.GDExtensionConstTypePtr{@ptrCast(&action)};
    _ = gde_call.callInstance(
        ctx(),
        "Input",
        "is_action_pressed",
        api.hashes.Input_is_action_pressed,
        input,
        &args,
        @ptrCast(&out),
    );
    return out;
}

fn inputIsActionJustPressed(action_z: [:0]const u8) u8 {
    const input = ensureInput() orelse return 0;
    var action = gde_call.makeStringName(ctx(), action_z);
    defer gde_call.destroyStringName(ctx(), &action);

    var out: u8 = 0;
    const args = [_]baseline_gde_if.GDExtensionConstTypePtr{@ptrCast(&action)};
    _ = gde_call.callInstance(
        ctx(),
        "Input",
        "is_action_just_pressed",
        api.hashes.Input_is_action_just_pressed,
        input,
        &args,
        @ptrCast(&out),
    );
    return out;
}

fn inputGetAxis(neg_z: [:0]const u8, pos_z: [:0]const u8) f64 {
    const input = ensureInput() orelse return 0;
    var neg = gde_call.makeStringName(ctx(), neg_z);
    defer gde_call.destroyStringName(ctx(), &neg);
    var pos = gde_call.makeStringName(ctx(), pos_z);
    defer gde_call.destroyStringName(ctx(), &pos);

    var out: f64 = 0;
    const args = [_]baseline_gde_if.GDExtensionConstTypePtr{
        @ptrCast(&neg),
        @ptrCast(&pos),
    };
    _ = gde_call.callInstance(
        ctx(),
        "Input",
        "get_axis",
        api.hashes.Input_get_axis,
        input,
        &args,
        @ptrCast(&out),
    );
    return out;
}

fn node3dGetPosition() api.Vector3 {
    const obj = api.g_godot_roc_current orelse return .{ .x = 0, .y = 0, .z = 0 };
    var out: api.Vector3 = .{ .x = 0, .y = 0, .z = 0 };
    _ = gde_call.callInstance(
        ctx(),
        "Node3D",
        "get_position",
        api.hashes.Node3D_get_position,
        obj,
        null,
        @ptrCast(&out),
    );
    return out;
}

fn node3dSetPosition(p: api.Vector3) void {
    const obj = api.g_godot_roc_current orelse return;
    var pos = p;
    const args = [_]baseline_gde_if.GDExtensionConstTypePtr{@ptrCast(&pos)};
    _ = gde_call.callInstance(
        ctx(),
        "Node3D",
        "set_position",
        api.hashes.Node3D_set_position,
        obj,
        &args,
        null,
    );
}

fn isActionPressed(action: [:0]const u8) bool {
    ensureInput();
    if (g_input == null) return false;

    var action_sn = gde_call.makeStringName(ctx(), action);
    defer gde_call.destroyStringName(ctx(), &action_sn);

    var exact: baseline_gde_if.GDExtensionBool = 0;
    const args = [_]baseline_gde_if.GDExtensionConstTypePtr{
        @ptrCast(&action_sn),
        @ptrCast(&exact),
    };
    var ret: baseline_gde_if.GDExtensionBool = 0;
    _ = gde_call.callInstance(
        ctx(),
        "Input",
        "is_action_pressed",
        api.hashes.Input_is_action_pressed,
        g_input,
        &args,
        @ptrCast(&ret),
    );
    return ret != 0;
}

// export fn godot_roc_input_is_action_pressed(action: abi.RocStr) callconv(.c) baseline_gde_if.GDExtensionBool {
//     const roc_host = g_roc_host.?;
//     var owned = action;
//     defer owned.decref(roc_host);

//     var buf: [64]u8 = undefined;
//     const s = owned.asSlice();
//     if (s.len >= buf.len) return 0;
//     @memcpy(buf[0..s.len], s);
//     buf[s.len] = 0;
//     return if (isActionPressed(buf[0..s.len :0])) 1 else 0;
// }

threadlocal var roc_str_buf: [512]u8 = undefined;

fn rocStrToZ(str: abi.RocStr) [:0]const u8 {
    const s = str.asSlice();
    if (s.len >= roc_str_buf.len) {
        roc_str_buf[0] = 0;
        return roc_str_buf[0..0 :0];
    }
    if (s.len > 0) {
        @memcpy(roc_str_buf[0..s.len], s);
    }
    roc_str_buf[s.len] = 0;
    return roc_str_buf[0..s.len :0];
}

export fn godot_roc_input_is_action_pressed(action: abi.RocStr) callconv(.c) u8 {
    var owned = action;
    defer owned.decref(g_roc_host.?);

    return inputIsActionPressed(rocStrToZ(owned));
}

export fn godot_roc_input_is_action_just_pressed(action: abi.RocStr) callconv(.c) u8 {
    var owned = action;
    defer owned.decref(g_roc_host.?);
    return inputIsActionJustPressed(rocStrToZ(owned));
}

export fn godot_roc_input_get_axis(neg: abi.RocStr, pos: abi.RocStr) callconv(.c) f64 {
    var n = neg;
    var p = pos;
    defer n.decref(g_roc_host.?);
    defer p.decref(g_roc_host.?);
    return inputGetAxisFromRoc(n, p);
}

fn inputGetAxisFromRoc(neg: abi.RocStr, pos: abi.RocStr) f64 {
    var neg_buf: [256]u8 = undefined;
    var pos_buf: [256]u8 = undefined;
    const nz = copyRocStrToBuf(neg, &neg_buf);
    const pz = copyRocStrToBuf(pos, &pos_buf);
    return inputGetAxis(nz, pz);
}

fn copyRocStrToBuf(str: abi.RocStr, buf: []u8) [:0]const u8 {
    const s = str.asSlice();
    if (s.len >= buf.len) {
        buf[0] = 0;
        return buf[0..0 :0];
    }
    if (s.len > 0) @memcpy(buf[0..s.len], s);
    buf[s.len] = 0;
    return buf[0..s.len :0];
}

export fn godot_roc_node3d_get_position() callconv(.c) api.Vector3 {
    return node3dGetPosition();
}

export fn godot_roc_node3d_set_position(p: api.Vector3) callconv(.c) void {
    node3dSetPosition(p);
}

// host.zig — already have is_action_pressed; add if missing:

export fn godot_roc_input_is_action_just_released(action: abi.RocStr) callconv(.c) u8 {
    var owned = action;
    defer owned.decref(g_roc_host.?);
    return inputIsActionJustReleased(rocStrToZ(owned));
}

fn inputIsActionJustReleased(action_z: [:0]const u8) u8 {
    const input = ensureInput() orelse return 0;
    var sn = gde_call.makeStringName(ctx(), action_z);
    defer gde_call.destroyStringName(ctx(), &sn);
    var out: u8 = 0;
    const args = [_]baseline_gde_if.GDExtensionConstTypePtr{@ptrCast(&sn)};
    _ = gde_call.callInstance(
        ctx(),
        "Input",
        "is_action_just_released",
        api.hashes.Input_is_action_just_released,
        input,
        &args,
        @ptrCast(&out),
    );
    return out;
}

// ---------------------------------------------------------------------------
// Logging / init
// ---------------------------------------------------------------------------

fn printWarn(comptime fmt: []const u8, args: anytype) void {
    var buf: [512]u8 = undefined;
    const msg = bufPrintC(&buf, "[godot-roc] " ++ fmt, args) catch {
        g_engine_interface.print_warning(
            "[godot-roc] (print truncated)",
            "printWarn",
            "host.zig",
            @src().line,
            0,
        );
        return;
    };
    if (comptime is_native_target) {
        std.debug.print("{s}\n", .{msg});
    }
    g_engine_interface.print_warning(msg.ptr, "printWarn", "host.zig", @src().line, 0);
}

fn printError(comptime fmt: []const u8, args: anytype) void {
    var buf: [512]u8 = undefined;
    const msg = bufPrintC(&buf, "[godot-roc] " ++ fmt, args) catch {
        g_engine_interface.print_error(
            "[godot-roc] (print truncated)",
            "printError",
            "host.zig",
            @src().line,
            0,
        );
        return;
    };
    if (comptime is_native_target) {
        std.debug.print("{s}\n", .{msg});
    }
    g_engine_interface.print_error(msg.ptr, "printError", "host.zig", @src().line, 0);
}

fn initialize(userdata: ?*anyopaque, level: baseline_gde_if.GDExtensionInitializationLevel) callconv(.c) void {
    _ = userdata;

    if (level == .initialization_core) {
        printWarn("initialize(level=core)\n", .{});
        return;
    }
    if (level == .initialization_servers) {
        printWarn("initialize(level=servers)\n", .{});
        return;
    }
    if (level == .initialization_scene) {
        printWarn("initialize(level=scene)\n", .{});
        ensureRocHost();
        godot_roc_scene_init();
        return;
    }
    if (level == .initialization_editor) {
        printWarn("initialize(level=editor)\n", .{});
        return;
    }
}

fn deinitialize(userdata: ?*anyopaque, level: baseline_gde_if.GDExtensionInitializationLevel) callconv(.c) void {
    _ = userdata;
    if (level == .initialization_core) {
        printWarn("deinitialize(level=core)\n", .{});
        return;
    }
    if (level == .initialization_servers) {
        printWarn("deinitialize(level=servers)\n", .{});
        return;
    }
    if (level == .initialization_scene) {
        printWarn("deinitialize(level=scene)\n", .{});
        return;
    }
    if (level == .initialization_editor) {
        printWarn("deinitialize(level=editor)\n", .{});
        return;
    }
}

fn ensureRocHost() void {
    printWarn("roc_initialize()\n", .{});
    if (g_roc_host != null) return;

    g_roc_fba_state = std.heap.FixedBufferAllocator.init(&g_roc_memory);
    const allocator = g_roc_fba_state.allocator();

    g_roc_host_env = HostEnv{ .roc_env = undefined };
    const env = &g_roc_host_env.?;
    env.roc_env = .{
        .allocator = allocator,
        .roc_io = abi.RocIo.default(),
    };

    g_roc_host_storage = abi.makeRocHost(&env.roc_env);
    g_roc_host = &g_roc_host_storage;
    gde_call.g_roc_host = g_roc_host;

    printWarn("ensureRocHost: ready (wasm={})\n", .{comptime is_wasm_target});
    printWarn("roc_initialized()\n", .{});
}

const HostEnv = struct {
    roc_env: abi.RocEnv,
};

// ---------------------------------------------------------------------------
// Class registration / instances
// ---------------------------------------------------------------------------

const GodotRocClassInfo = struct {
    name: [MAX_NAME_LEN + 1]u8 = undefined,
    parent: [MAX_NAME_LEN + 1]u8 = undefined,
    name_len: u8 = 0,
    parent_len: u8 = 0,
    class_id: u32 = 0,

    fn nameZ(self: *const GodotRocClassInfo) [:0]const u8 {
        return self.name[0..self.name_len :0];
    }
    fn parentZ(self: *const GodotRocClassInfo) [:0]const u8 {
        return self.parent[0..self.parent_len :0];
    }
};

const GodotRocObjectInstance = struct {
    object: baseline_gde_if.GDExtensionObjectPtr,
    class_id: u32,
    instance_id: u64,
    /// App-defined layout. Roc interprets indices (hp, mana, flags, …).
    /// F32 lives in the low 32 bits via @bitCast; U32 similarly.
    user_slots: [USER_SLOT_COUNT]u64 = [_]u64{0} ** USER_SLOT_COUNT,
};

fn requireCurrentObject() baseline_gde_if.GDExtensionObjectPtr { // ?*GodotRocObjectInstance
    return api.g_godot_roc_current;
    //const p = api.g_godot_roc_current orelse return null;
    //return @ptrCast(@alignCast(p));
}

// fn setCurrent(inst: ?*GodotRocObjectInstance) void {
//     api.g_godot_roc_current = if (inst) |i| @ptrCast(i) else null;
// }

fn classInstanceFromInstance(instance: baseline_gde_if.GDExtensionClassInstancePtr) *GodotRocObjectInstance {
    return @ptrCast(@alignCast(instance));
}

var g_instance_buf: [256 * 1024]u8 = undefined;
var g_instance_fba: std.heap.FixedBufferAllocator = undefined;
var g_instance_fba_ready = false;

fn instanceAllocator() std.mem.Allocator {
    if (!g_instance_fba_ready) {
        g_instance_fba = std.heap.FixedBufferAllocator.init(&g_instance_buf);
        g_instance_fba_ready = true;
    }
    return g_instance_fba.allocator();
}

fn createInstance(
    p_class_userdata: ?*anyopaque,
    notify_postinitialize: baseline_gde_if.GDExtensionBool,
) callconv(.c) baseline_gde_if.GDExtensionObjectPtr {
    _ = notify_postinitialize;
    printWarn("createInstance(...)\n", .{});

    const info: *const GodotRocClassInfo = @ptrCast(@alignCast(p_class_userdata orelse return null));

    var parent_sn = gde_call.makeStringName(ctx(), info.parentZ());
    defer gde_call.destroyStringName(ctx(), &parent_sn);
    var class_sn = gde_call.makeStringName(ctx(), info.nameZ());
    defer gde_call.destroyStringName(ctx(), &class_sn);

    const obj = g_engine_interface.classdb_construct_object2(@ptrCast(&parent_sn));
    if (obj == null) return null;

    const self = instanceAllocator().create(GodotRocObjectInstance) catch return null;
    self.* = .{
        .object = obj,
        .class_id = info.class_id,
        .instance_id = g_next_instance_id,
        .user_slots = [_]u64{0} ** USER_SLOT_COUNT,
    };
    g_next_instance_id += 1;

    g_engine_interface.object_set_instance(obj, @ptrCast(&class_sn), @ptrCast(self));
    return obj;
}

fn recreateInstance(
    p_class_userdata: ?*anyopaque,
    p_object: baseline_gde_if.GDExtensionObjectPtr,
) callconv(.c) baseline_gde_if.GDExtensionClassInstancePtr {
    printWarn("recreateInstance(...)\n", .{});
    const info: *const GodotRocClassInfo = @ptrCast(@alignCast(p_class_userdata orelse return null));

    const self = instanceAllocator().create(GodotRocObjectInstance) catch return null;
    self.* = .{
        .object = p_object,
        .class_id = info.class_id,
        .instance_id = g_next_instance_id,
        .user_slots = [_]u64{0} ** USER_SLOT_COUNT,
    };
    g_next_instance_id += 1;

    var class_sn = gde_call.makeStringName(ctx(), info.nameZ());
    defer gde_call.destroyStringName(ctx(), &class_sn);
    g_engine_interface.object_set_instance(p_object, @ptrCast(&class_sn), @ptrCast(self));
    return @ptrCast(self);
}

fn freeInstance(p_class_userdata: ?*anyopaque, p_instance: baseline_gde_if.GDExtensionClassInstancePtr) callconv(.c) void {
    _ = p_class_userdata;
    printWarn("freeInstance(...)\n", .{});
    const self: *GodotRocObjectInstance = @ptrCast(@alignCast(p_instance));
    instanceAllocator().destroy(self);
}

fn registerClass(info: *GodotRocClassInfo) void {
    printWarn("registerClass(info: *ClassInfo) void\n", .{});

    var class_sn = gde_call.makeStringName(ctx(), info.nameZ());
    defer gde_call.destroyStringName(ctx(), &class_sn);
    var parent_sn = gde_call.makeStringName(ctx(), info.parentZ());
    defer gde_call.destroyStringName(ctx(), &parent_sn);

    var creation: baseline_gde_if.GDExtensionClassCreationInfo5 = undefined;
    @memset(@as([*]u8, @ptrCast(&creation))[0..@sizeOf(@TypeOf(creation))], 0);

    creation.is_exposed = 1;
    creation.create_instance_func = createInstance;
    creation.free_instance_func = freeInstance;
    creation.recreate_instance_func = recreateInstance;
    creation.get_virtual_func = @ptrCast(@constCast(&getVirtual));
    creation.class_userdata = info;

    g_engine_interface.classdb_register_extension_class5(
        g_engine_library,
        @ptrCast(&class_sn),
        @ptrCast(&parent_sn),
        &creation,
    );

    printWarn("registered {s} : {s} (id={d})\n", .{ info.nameZ(), info.parentZ(), info.class_id });
}

fn requireCurrentInstance() ?*GodotRocObjectInstance {
    return g_godot_roc_current_instance;
}

// ---------------------------------------------------------------------------
// Virtuals / editor hint
// ---------------------------------------------------------------------------

fn ensureEngine() void {
    if (g_engine_singleton != null) return;
    g_engine_singleton = gde_call.getSingleton(ctx(), "Engine");
}

fn isEditorHint() bool {
    ensureEngine();
    if (g_engine_singleton == null) return false;
    var ret: baseline_gde_if.GDExtensionBool = 0;
    _ = gde_call.callInstance(
        ctx(),
        "Engine",
        "is_editor_hint",
        api.hashes.Engine_is_editor_hint,
        g_engine_singleton,
        null,
        @ptrCast(&ret),
    );
    return ret != 0;
}

fn onReady(
    p_instance: baseline_gde_if.GDExtensionClassInstancePtr,
    p_args: [*c]const baseline_gde_if.GDExtensionConstTypePtr,
    p_ret: baseline_gde_if.GDExtensionTypePtr,
) callconv(.c) void {
    _ = p_args;
    _ = p_ret;
    if (isEditorHint()) return;
    const self = classInstanceFromInstance(p_instance);

    const prev_obj = api.g_godot_roc_current;
    const prev_inst = g_godot_roc_current_instance;
    api.g_godot_roc_current = self.object;
    api.g_godot_roc_current_class_id = self.class_id;
    g_godot_roc_current_instance = self;
    defer {
        api.g_godot_roc_current = prev_obj;
        g_godot_roc_current_instance = prev_inst;
        if (prev_inst) |p| {
            api.g_godot_roc_current_class_id = p.class_id;
        } else {
            api.g_godot_roc_current_class_id = 0;
        }
    }
    // Prefer:
    // defer {
    //     api.g_godot_roc_current = prev_obj;
    //     g_godot_roc_current_instance = prev_inst;
    //     if (prev_inst) |p| api.g_godot_roc_current_class_id = p.class_id else api.g_godot_roc_current_class_id = 0;
    // }

    godot_roc_ready();
}

fn onPhysicsProcess(
    p_instance: baseline_gde_if.GDExtensionClassInstancePtr,
    p_args: [*c]const baseline_gde_if.GDExtensionConstTypePtr,
    p_ret: baseline_gde_if.GDExtensionTypePtr,
) callconv(.c) void {
    _ = p_ret;
    if (isEditorHint()) return;
    const delta: f64 = @as(*const f64, @ptrCast(@alignCast(p_args[0]))).*;
    const self = classInstanceFromInstance(p_instance);

    const prev_obj = api.g_godot_roc_current;
    const prev_inst = g_godot_roc_current_instance;
    api.g_godot_roc_current = self.object;
    api.g_godot_roc_current_class_id = self.class_id;
    g_godot_roc_current_instance = self;
    defer {
        api.g_godot_roc_current = prev_obj;
        g_godot_roc_current_instance = prev_inst;
        if (prev_inst) |p| {
            api.g_godot_roc_current_class_id = p.class_id;
        } else {
            api.g_godot_roc_current_class_id = 0;
        }
    }
    // Prefer:
    // defer {
    //     api.g_godot_roc_current = prev_obj;
    //     g_godot_roc_current_instance = prev_inst;
    //     if (prev_inst) |p| api.g_godot_roc_current_class_id = p.class_id else api.g_godot_roc_current_class_id = 0;
    // }

    godot_roc_physics_process(self.class_id, delta);
}

fn onProcess(
    p_instance: baseline_gde_if.GDExtensionClassInstancePtr,
    p_args: [*c]const baseline_gde_if.GDExtensionConstTypePtr,
    p_ret: baseline_gde_if.GDExtensionTypePtr,
) callconv(.c) void {
    _ = p_ret;
    if (isEditorHint()) return;
    const delta: f64 = @as(*const f64, @ptrCast(@alignCast(p_args[0]))).*;
    const self = classInstanceFromInstance(p_instance);

    const prev_obj = api.g_godot_roc_current;
    const prev_inst = g_godot_roc_current_instance;
    api.g_godot_roc_current = self.object;
    api.g_godot_roc_current_class_id = self.class_id;
    g_godot_roc_current_instance = self;
    defer {
        api.g_godot_roc_current = prev_obj;
        g_godot_roc_current_instance = prev_inst;
        if (prev_inst) |p| {
            api.g_godot_roc_current_class_id = p.class_id;
        } else {
            api.g_godot_roc_current_class_id = 0;
        }
    }
    // Prefer:
    // defer {
    //     api.g_godot_roc_current = prev_obj;
    //     g_godot_roc_current_instance = prev_inst;
    //     if (prev_inst) |p| api.g_godot_roc_current_class_id = p.class_id else api.g_godot_roc_current_class_id = 0;
    // }

    godot_roc_process(self.class_id, delta);
}

fn getVirtual(
    class_userdata: ?*anyopaque,
    name: baseline_gde_if.GDExtensionConstStringNamePtr,
    hash: u32,
) callconv(.c) ?baseline_gde_if.GDExtensionClassCallVirtual {
    _ = class_userdata;
    if (hash == api.hashes.Node__ready) return onReady;
    if (stringNameEq(name, "_process")) return onProcess;
    if (stringNameEq(name, "_physics_process")) return onPhysicsProcess;
    return null;
}

fn stringNameEq(
    name: baseline_gde_if.GDExtensionConstStringNamePtr,
    text: [:0]const u8,
) bool {
    var other = gde_call.makeStringName(ctx(), text);
    defer gde_call.destroyStringName(ctx(), &other);

    const eval = g_engine_interface.variant_get_ptr_operator_evaluator(
        baseline_gde_if.GDExtensionVariantOperator.equal,
        baseline_gde_if.GDExtensionVariantType.string_name,
        baseline_gde_if.GDExtensionVariantType.string_name,
    );
    var result: baseline_gde_if.GDExtensionBool = 0;
    eval(@ptrCast(name), @ptrCast(&other), @ptrCast(&result));
    return result != 0;
}
