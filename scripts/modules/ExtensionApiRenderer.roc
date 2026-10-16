import ModMap
import CpuArchOS
import ExtensionApi exposing [
    #ExtensionApi,
    MethodDef,
    UtilityFunction,
    Singleton,
    BuiltinClass,
    ClassDef,
    SignalDef,
    EnumDef,
    PropertyDef,
]

ExtensionApiRenderer := {}.{

    render_godot_roc_module = || {
        \\## A module specifically just for this bindings project
        \\GodotRoc := [].{
        \\    ClassId : U32
        \\    Bool : U8
        \\
        \\    false : GodotRoc.Bool
        \\    false = 0.U8
        \\
        \\    true : GodotRoc.Bool
        \\    true = 1.U8
        \\}
    }

    render_engine_module = || {
        \\import Host
        \\import engine/math/Vector3
        \\import GodotRoc
        \\
        \\
        \\## A generic godot-4.x-like game engine interface, with multi-engine & multi-version support.
        \\Engine := [].{
        \\
        \\# hard coded for now, detect avaliable comptime arch & engine later...
        \\CpuArch : [X64musl, Wasm32]
        \\Godot4_7Module :: { godot4_7_instance_field: U32 }.{
        \\    godot4_7_static_field : U32
        \\    godot4_7_static_field = 0
        \\}
        \\Redot26_2Module :: { godot26_2_instance_field: U32 }.{
        \\    godot26_2_static_field : U32
        \\    godot26_2_static_field = 0
        \\}
        \\Blazium0_6Module :: { blazium0_6_instance_field: U32 }.{
        \\    blazium0_6_static_field : U32
        \\    blazium0_6_static_field = 0
        \\}
        \\EngineModuleTagUnion : [Godot4_7Tag(Godot4_7Module), Redot26_2Tag(Redot26_2Module), Blazium0_6Tag(Blazium0_6Module)]
        \\
        \\    current_engine! : () => EngineModuleTagUnion
        \\    current_engine! = || {
        \\        engine : EngineModuleTagUnion
        \\        engine = match Host.current_engine!() {
        \\            0 => Godot4_7Tag({ godot4_7_instance_field: 0 })
        \\            1 => Redot26_2Tag({ godot26_2_instance_field: 0 })
        \\            2 => Blazium0_6Tag({ blazium0_6_static_field: 0 })
        \\            _ => crash "Host.current_engine!() got unexpected tag union value."
        \\        }
        \\        engine
        \\    }
        \\
        \\    current_target! : () => CpuArch
        \\    current_target! = ||{
        \\        target : CpuArch
        \\        target = match Host.current_target!() {
        \\            0 => X64musl
        \\            1 => Wasm32
        \\            _ => crash "Host.current_target!() got unexpected tag union value."
        \\        }
        \\        target
        \\    }
        \\
        \\    engine_runtime_ok! : () => U8
        \\    engine_runtime_ok! = Host.engine_runtime_ok!
        \\
        \\    register_class! : Str, Str => GodotRoc.ClassId
        \\    register_class! = |class_name, parent_class_name|
        \\        Host.register_class!(class_name, parent_class_name)
        \\
        \\    print_error! : Str => {}
        \\    print_error! = |str|
        \\        Host.print_error!(str)
        \\
        \\    print_warning! : Str => {}
        \\    print_warning! = |str|
        \\        Host.print_warning!(str)
        \\
        \\    instance_id! : () => U64
        \\    instance_id! = Host.instance_id!
        \\
        \\    instance_class_id! : () => U32
        \\    instance_class_id! = Host.instance_class_id!
        \\
        \\    user_slot_count! : () => U64
        \\    user_slot_count! = Host.user_slot_count!
        \\
        \\    user_slot_get! : U64 => U64
        \\    user_slot_get! = Host.user_slot_get!
        \\
        \\    user_slot_set! : U64, U64 => {}
        \\    user_slot_set! = Host.user_slot_set!
        \\
        \\    user_slot_get_f32! : U64 => F32
        \\    user_slot_get_f32! = Host.user_slot_get_f32!
        \\
        \\    user_slot_set_f32! : U64, F32 => {}
        \\    user_slot_set_f32! = Host.user_slot_set_f32!
        \\}
        \\
        \\
        \\
        \\
        \\# Engine-specific extensions (can be empty records for now)
        \\Godot4_5Api :: [].{ }          # pure baseline
        \\Godot4_7Api :: [].{
        \\    exclusive_spell = 5
        \\    #exclusive_spell! : () => F32     # e.g. Godot-only ability
        \\    #procedural_map_v2! : () => {}
        \\}
        \\Redot26_2Api :: [].{
        \\    exclusive_map = 7.7
        \\    #exclusive_ability! : () => U32   # Redot-only ability
        \\    #redot_terrain_gen! : () => {}
        \\}
    }

    render_engine_info_module : ExtensionApi -> Str
    render_engine_info_module = |eapi| {
        # TODO: detect engine fork: Godot vs Redot, using "Engine" for ambigous generic term for now.
        # TODO: Implement PlatformApi, "engine avalibility @ compile time"
        # TODO: Implement Richard's target suggestion: https://roc.zulipchat.com/#narrow/channel/231634-beginners/topic/.E2.9C.94.20OS-specific.20APIs.20in.20platforms/with/630287727
        # "engine avalibility @ runtime & game dev time, with type checker enforcing multi-engine engine-call correctness."
        # TODO: support multiple engine combinations, Godot4_7 + Redot26, etc.
        major = eapi.header.version_major.to_str()
        minor = eapi.header.version_minor.to_str()
        patch = eapi.header.version_patch.to_str()
        full = eapi.header.version_full_name
        \\## AUTO-GENERATED from extension_api.json header
        \\EngineInfo := [].{
        \\    version_major : U64
        \\    version_major = ${major}
        \\
        \\    version_minor : U64
        \\    version_minor = ${minor}
        \\
        \\    version_patch : U64
        \\    version_patch = ${patch}
        \\
        \\    version_full_name : Str
        \\    version_full_name = ${Str.inspect(full)} # escape quotes...
        \\
        \\    ## Compile-time identity of this platform package
        \\    PlatformApi : [Godot4_7] # hard coded for now... TODO: add multi engine...
        \\    platform_api : PlatformApi
        \\    platform_api = Godot4_7
        \\}
    }

    render_platform_main : ExtensionApi, List(CpuArchOS), List(CpuArchOS) -> Str
    render_platform_main = |eapi, selected_targets, all_targets| {
        builtin_names =
            eapi.builtin_classes.fold([], |acc, b| {
                if ExtensionApiRenderer.is_struct_builtin(b.name) {
                    acc
                } else {
                    List.append(acc, builtin_module_name(b.name))
                }
            })

        class_names = eapi.classes.map(|c| ModMap.class_module_name(c.name))
        singleton_names = eapi.singletons.map(|s| ModMap.singleton_module_name(s.name))

        meta_names = [
            "Host",
            "GlobalConstants",
            "GlobalEnums",
            "BuiltinClassSizes",
            "BuiltinClassMemberOffsets",
            "NativeStructures",
            "UtilityFunctions",
            "EngineInfo",
        ]

        math_method_names =
            eapi.builtin_classes.fold([], |acc, b| {
                if ExtensionApiRenderer.is_struct_builtin(b.name) {
                    match b.methods {
                        Ok(ms) if !(ms.is_empty()) =>
                            List.append(acc, "${b.name}Methods")
                        _ => acc
                    }
                } else {
                    acc
                }
            })

        all_names =
            List.concat(
                meta_names,
                List.concat(
                    ExtensionApiRenderer.math_type_names,
                    List.concat(
                        math_method_names,
                        List.concat(builtin_names, List.concat(class_names, singleton_names)),
                    ),
                ),
            )

        math_method_imports =
            Str.join_with(
                math_method_names.map(|n| "import engine/math/${n}"),
                "\n",
            )

        expose = Str.join_with(all_names.map(|n| "        ${n}"), ",\n")
        hosted_body = Str.join_with(all_host_symbols(eapi).map(hosted_entry), "\n")

        meta_imports =
            \\import Host
            \\import EngineInfo
            \\import engine/GlobalConstants
            \\import engine/GlobalEnums
            \\import engine/BuiltinClassSizes
            \\import engine/BuiltinClassMemberOffsets
            \\import engine/NativeStructures
            \\import engine/UtilityFunctions

        math_imports =
            Str.join_with(ExtensionApiRenderer.math_type_names.map(|n| "import engine/math/${n}"), "\n")
        builtin_imports =
            Str.join_with(builtin_names.map(|n| "import engine/builtin_classes/${n}"), "\n")
        class_imports =
            Str.join_with(class_names.map(|n| "import engine/classes/${n}"), "\n")
        singleton_imports =
            Str.join_with(singleton_names.map(|n| "import engine/singletons/${n}"), "\n")

        targets_block = render_targets_block(selected_targets, all_targets)

        \\# AUTO-GENERATED Godot Roc platform
        \\platform "godot-roc"
        \\    requires {} {
        \\        scene_init! : () => {},
        \\        ready! : () => {},
        \\        process! : GodotRoc.ClassId, F64 => {},
        \\        physics_process! : GodotRoc.ClassId, F64 => {},
        \\    }
        \\    exposes [
        \\        Engine,
        \\        GodotRoc,
        \\${expose}
        \\    ]
        \\    packages { }
        \\    provides {
        \\        "godot_roc_scene_init": scene_init_for_host!,
        \\        "godot_roc_ready": ready_for_host!,
        \\        "godot_roc_process": process_for_host!,
        \\        "godot_roc_physics_process": physics_process_for_host!,
        \\    }
        \\    hosted {
        \\${hosted_body}
        \\    }
        \\${targets_block}
        \\${meta_imports}
        \\
        \\${math_imports}
        \\
        \\${math_method_imports}
        \\
        \\${builtin_imports}
        \\
        \\${class_imports}
        \\
        \\${singleton_imports}
        \\
        \\import Engine
        \\import Host
        \\import GodotRoc
        \\
        \\scene_init_for_host! : () => {}
        \\scene_init_for_host! = || {
        \\    _ = scene_init!()
        \\    {}
        \\}
        \\
        \\ready_for_host! : () => {}
        \\ready_for_host! = || {
        \\    _ = ready!()
        \\    {}
        \\}
        \\
        \\process_for_host! : GodotRoc.ClassId, F64 => {}
        \\process_for_host! = |class_id, delta| {
        \\    _ = process!(class_id, delta)
        \\    {}
        \\}
        \\
        \\physics_process_for_host! : GodotRoc.ClassId, F64 => {}
        \\physics_process_for_host! = |class_id, delta| {
        \\    _ = physics_process!(class_id, delta)
        \\    {}
        \\}
    }

    render_host_module : ExtensionApi -> Str
    render_host_module = |eapi| {

        sing_decls =
            Str.join_with(
                eapi.singletons.map(|s| {
                    sym = host_singleton_symbol(s.name)
                    host_entry(sym, "()", "U64")
                }),
                "\n",
            )

        util_decls =
            Str.join_with(
                eapi.utility_functions.map(|uf| {
                    ret =
                        match uf.return_type {
                            Ok(rt) => c_to_host_type(rt)
                            _ => "{}"
                        }
                    args =
                        match uf.arguments {
                            Ok(a) if !(a.is_empty()) =>
                                Str.join_with(a.map(|x| c_to_host_type(x.type)), ", ")
                            _ => "()"
                        }
                    sym = host_util_symbol(uf.name, u64_or_0(uf.hash))
                    host_entry(sym, args, ret)
                }),
                "\n",
            )

        builtin_method_decls =
            Str.join_with(
                eapi.builtin_classes.map(|bic| {
                    match bic.methods {
                        Ok(ms) =>
                            Str.join_with(
                                ms.map(|md| {
                                    sym = host_method_symbol(bic.name, md.name, u64_or_0(md.hash))
                                    host_entry(sym, method_arg_types_host_for(bic.name, md), method_return_type_host(md))
                                }),
                                "\n",
                            )
                        _ => ""
                    }
                }),
                "\n",
            )

        class_method_decls =
            Str.join_with(
                eapi.classes.map(|cls| {
                    match cls.methods {
                        Ok(ms) =>
                            Str.join_with(
                                ms.map(|md| {
                                    sym = host_method_symbol(cls.name, md.name, u64_or_0(md.hash))
                                    host_entry(sym, method_arg_types_host(md), method_return_type_host(md))
                                }),
                                "\n",
                            )
                        _ => ""
                    }
                }),
                "\n",
            )

        math_imports =
            Str.join_with(
                math_type_names.map(|n| "import engine/math/${n}"),
                "\n",
            )

        \\# AUTO-GENERATED Host surface — signatures only; bodies via platform hosted → Zig
        \\${math_imports}
        \\
        \\Host := [].{
        \\${host_facade_decls}
        \\
        \\    # --- singletons ---
        \\${sing_decls}
        \\
        \\    # --- utility functions ---
        \\${util_decls}
        \\
        \\    # --- builtin methods ---
        \\${builtin_method_decls}
        \\
        \\    # --- class methods ---
        \\${class_method_decls}
        \\}
    }

    render_zig_platform_abi_impl : ExtensionApi -> Str
    render_zig_platform_abi_impl = |eapi| {
        structs = zig_all_extern_structs(eapi)
        hashes = zig_hashes_struct(eapi)

        sings = Str.join_with(eapi.singletons.map(zig_export_singleton), "\n")
        utils = Str.join_with(eapi.utility_functions.map(zig_export_util), "\n")

        builtin_methods =
            Str.join_with(
                eapi.builtin_classes.map(|bic| {
                    match bic.methods {
                        Ok(ms) => Str.join_with(ms.map(|md| zig_export_method(eapi, bic.name, md)), "\n")
                        _ => ""
                    }
                }),
                "\n",
            )

        class_methods =
            Str.join_with(
                eapi.classes.map(|cls| {
                    match cls.methods {
                        Ok(ms) => Str.join_with(ms.map(|md| zig_export_method(eapi, cls.name, md)), "\n")
                        _ => ""
                    }
                }),
                "\n",
            )

        \\//! AUTO-GENERATED from dump-out/godot/extension_api.json
        \\const std = @import("std");
        \\const gde_call = @import("gde_call.zig");
        \\const baseline_gde_if = @import("gdextension_interface.zig");
        \\const abi = @import("roc_platform_abi.zig");
        \\
        \\//const GodotRocObjectInstance = extern struct {
        \\//    object: ?*anyopaque,
        \\//    class_id: u32,
        \\//};
        \\
        \\/// Current Object for generated class instance methods (Host ABI has no self_ptr).
        \\/// host.zig assigns this during virtuals / before façade calls.
        \\pub var g_godot_roc_current: ?*anyopaque = null; // baseline_gde_if.GDExtensionObjectPtr
        \\pub var g_godot_roc_current_class_id: u32 = 0;
        \\
        \\${structs}
        \\
        \\${hashes}
        \\
        \\${zig_facade_note}
        \\
        \\${sings}
        \\${utils}
        \\${builtin_methods}
        \\${class_methods}
        \\
    }

    render_global_constants_module : ExtensionApi -> Str
    render_global_constants_module = |eapi| {
        body =
            Str.join_with(
                eapi.global_constants.map(|gc| {
                    vn = to_value_name(gc.name)
                    \\    ${vn} : I64
                    \\    ${vn} = ${gc.value.to_str()}
                }),
                "\n",
            )
        \\GlobalConstants := {
        \\}.{
        \\${body}
        \\}
    }


    render_global_enums_module : ExtensionApi -> Str
    render_global_enums_module = |eapi| {
        body =
            Str.join_with(
                eapi.global_enums.map(|e| {
                    ename = roc_type_ident(e.name)
                    values = Str.join_with(e.values.map(|v| v.name), ", ")
                    \\    ${ename} : [${values}]
                }),
                "\n",
            )
        \\GlobalEnums := {
        \\}.{
        \\${body}
        \\}
    }

    render_math_type_module : Str -> Str
    render_math_type_module = |name| {
        peers = math_type_peer_imports(name)
        fields = canonical_roc_fields(name)
        \\## Godot math value type (layout only — no Host, no methods)
        \\${peers}${name} := {
        \\${fields}
        \\}
    }

    builtin_module_name : Str -> Str
    builtin_module_name = |name| {
        match name {
            "bool" => "GodotBool"
            "int" => "GodotInt"
            "float" => "GodotFloat"
            other => other
        }
    }

    render_builtin_class_module : BuiltinClass -> Str
    render_builtin_class_module = |bic| {

        type_name = builtin_module_name(bic.name)

        members_list =
            match bic.members {
                Ok(ms) => ms
                _ => []
            }

        members_str =
            if !(members_list.is_empty()) {
                Str.join_with(members_list.map(|m| "    ${m.name} : ${member_to_roc_field_type(m.type)}"), ",\n")
            } else {
                "    ptr : U64"
            }

        construct_sig =
            if !(members_list.is_empty()) {
                arg_tys = Str.join_with(members_list.map(|m| member_to_roc_field_type(m.type)), ", ")
                arg_ns = Str.join_with(members_list.map(|m| m.name), ", ")
                \\    construct_default! : ${arg_tys} -> ${type_name}
                \\    construct_default! = |${arg_ns}| { { ${arg_ns} } }
            } else {
                \\    construct_default! : {} -> ${type_name}
                \\    construct_default! = |_| { { ptr: 0 } }
            }

        method_refs =
            match bic.methods {
                Ok(ms) =>
                    ms.fold([], |acc, md| {
                        acc1 =
                            match md.arguments {
                                Ok(args) =>
                                    args.fold(acc, |a2, arg|
                                        collect_type_refs(a2, type_name, c_to_roc_type(arg.type))
                                    )
                                _ => acc
                            }
                        ret_t =
                            match md.return_type {
                                Ok(rt) => Ok(c_to_roc_type(rt))
                                _ =>
                                    match md.return_value {
                                        Ok(rv) => Ok(c_to_roc_type(rv.type))
                                        _ => Err(Missing)
                                    }
                            }
                        match ret_t {
                            Ok(t) => collect_type_refs(acc1, type_name, t)
                            _ => acc1
                        }
                    })
                _ => []
            }

        math_refs =
            method_refs.fold([], |acc, t| {
                if ExtensionApiRenderer.is_struct_builtin(t) and !(List.contains(acc, t)) {
                    List.append(acc, t)
                } else {
                    acc
                }
            })

        math_imports =
            if List.is_empty(math_refs) {
                ""
            } else {
                Str.concat(
                    Str.join_with(math_refs.map(|t| "import ../../engine/math/${t}"), "\n"),
                    "\n",
                )
            }

        \\# builtin ${bic.name}
        \\import ../../Host
        \\${math_imports}
        \\${type_name} := {
        \\${members_str}
        \\}.{
        \\${construct_sig}
        \\${enums_block(bic.enums)}
        \\
        \\    # --- methods ---
        \\${methods_block_live(bic.name, bic.methods)}
        \\}
    }

    render_class_module : ClassDef -> Str
    render_class_module = |cls| {
        type_name = ModMap.class_module_name(cls.name)
        inherits_line =
            match cls.inherits {
                Ok(p) => "# inherits: ${p}\n"
                _ => ""
            }
        method_refs =
            match cls.methods {
                Ok(ms) =>
                    ms.fold([], |acc, md| {
                        acc1 =
                            match md.arguments {
                                Ok(args) =>
                                    args.fold(acc, |a2, arg|
                                        collect_type_refs(a2, type_name, c_to_roc_type(arg.type))
                                    )
                                _ => acc
                            }
                        ret_t =
                            match md.return_type {
                                Ok(rt) => Ok(c_to_roc_type(rt))
                                _ =>
                                    match md.return_value {
                                        Ok(rv) => Ok(c_to_roc_type(rv.type))
                                        _ => Err(Missing)
                                    }
                            }
                        match ret_t {
                            Ok(t) => collect_type_refs(acc1, type_name, t)
                            _ => acc1
                        }
                    })
                _ => []
            }
        needs_math_flag =
            method_refs.fold(Bool.False, |acc, t|
                if acc or ExtensionApiRenderer.is_struct_builtin(t) {
                    Bool.True
                } else {
                    Bool.False
                }
            )

        peer_imports =
            if needs_math_flag {
                Str.concat(
                    Str.join_with(
                        ExtensionApiRenderer.math_type_names.map(|t| "import ../../engine/math/${t}"),
                        "\n",
                    ),
                    "\n",
                )
            } else {
                ""
            }

        \\# class ${cls.name}
        \\import ../../Host
        \\${peer_imports}
        \\${inherits_line}${type_name} := {
        \\    ptr : U64,
        \\}.{
        \\${enums_block(cls.enums)}
        \\
        \\    # --- properties (getters/setters are methods) ---
        \\${properties_block_comments(cls.properties)}
        \\
        \\    # --- methods ---
        \\${methods_block_live(cls.name, cls.methods)}
        \\
        \\${signals_block(cls.signals)}
        \\}
    }

    render_singleton_module : ExtensionApi, Singleton -> Str
    render_singleton_module = |eapi, st| {
        mod_name = ModMap.singleton_module_name(st.name)
        sym = host_singleton_symbol(st.name)

        methods_src =
            eapi.classes.fold("", |acc, cls| {
                if cls.name == st.name {
                    methods_block_live(cls.name, cls.methods)
                } else {
                    acc
                }
            })

        needs_math =
            eapi.classes.fold(Bool.False, |acc, cls| {
                if cls.name != st.name {
                    acc
                } else {
                    match cls.methods {
                        Ok(ms) =>
                            ms.fold(acc, |a2, md| {
                                a3 =
                                    match md.arguments {
                                        Ok(args) =>
                                            args.fold(a2, |a4, arg|
                                                if ExtensionApiRenderer.is_struct_builtin(c_to_roc_type(arg.type)) {
                                                    Bool.True
                                                } else {
                                                    a4
                                                }
                                            )
                                        _ => a2
                                    }
                                ret_t = method_return_type_str(md)
                                if ExtensionApiRenderer.is_struct_builtin(c_to_roc_type(ret_t)) {
                                    Bool.True
                                } else {
                                    a3
                                }
                            })
                        _ => acc
                    }
                }
            })

        math_imports =
            if needs_math {
                Str.concat(
                    Str.join_with(
                        ExtensionApiRenderer.math_type_names.map(|t| "import ../../engine/math/${t}"),
                        "\n",
                    ),
                    "\n",
                )
            } else {
                ""
            }

        \\# singleton ${st.name} (Godot-aligned names → Host hashes)
        \\import ../../Host
        \\${math_imports}
        \\${mod_name} := {
        \\    ptr : U64,
        \\}.{
        \\    get! : () => ${mod_name}
        \\    get! = || { { ptr: Host.${sym}!() } }
        \\
        \\    # --- methods (same names as Godot) ---
        \\${methods_src}
        \\}
    }


    builtin_class_sizes_to_roc_source_str : ExtensionApi -> Str
    builtin_class_sizes_to_roc_source_str = |eapi| {
        body =
            Str.join_with(
                eapi.builtin_class_sizes.map(|bcs| {
                    lines =
                        Str.join_with(bcs.sizes.map(|ns| "    # ${ns.name} = ${ns.size.to_str()}"), "\n")
                    \\    # ${bcs.build_configuration}
                    \\${lines}
                }),
                "\n",
            )
        \\BuiltinClassSizes := {
        \\}.{
        \\${body}
        \\}
    }

    builtin_class_member_offsets_to_roc_source_str : ExtensionApi -> Str
    builtin_class_member_offsets_to_roc_source_str = |eapi| {
        body =
            Str.join_with(
                eapi.builtin_class_member_offsets.map(|bco| {
                    classes =
                        Str.join_with(
                            bco.classes.map(|bc| {
                                ms =
                                    Str.join_with(
                                        bc.members.map(|m| "    #   ${m.member} @ ${m.offset.to_str()}"),
                                        "\n",
                                    )
                                \\    # ${bc.name}
                                \\${ms}
                            }),
                            "\n",
                        )
                    \\    # ${bco.build_configuration}
                    \\${classes}
                }),
                "\n",
            )
        \\BuiltinClassMemberOffsets := {
        \\}.{
        \\${body}
        \\}
    }

    native_structures_to_roc_source_str : ExtensionApi -> Str
    native_structures_to_roc_source_str = |eapi| {
        body =
            Str.join_with(
                eapi.native_structures.map(|ns| "    # ${ns.name}: ${ns.format}"),
                "\n",
            )
        \\NativeStructures := {
        \\}.{
        \\${body}
        \\}
    }

    utility_functions_to_roc_source_str : ExtensionApi -> Str
    utility_functions_to_roc_source_str = |eapi| {
        body =
            Str.join_with(
                eapi.utility_functions.map(|uf| {
                    ret =
                        match uf.return_type {
                            Ok(rt) => c_to_host_type(rt)
                            _ => "{}"
                        }
                    args =
                        match uf.arguments {
                            Ok(a) if !(a.is_empty()) =>
                                Str.join_with(a.map(|x| c_to_host_type(x.type)), ", ")
                            _ => "()"
                        }
                    fn = roc_fn_name(uf.name)
                    sym = host_util_symbol(uf.name, u64_or_0(uf.hash))
                    \\    ${fn}! : ${args} => ${ret}
                    \\    ${fn}! = Host.${sym}!
                }),
                "\n",
            )
        \\import ../Host
        \\
        \\UtilityFunctions := {
        \\}.{
        \\${body}
        \\}
    }

    render_method_module : BuiltinClass -> Str
    render_method_module = |bic| {
        match bic.methods {
            Ok(ms) if !(ms.is_empty()) => {
                body = methods_block_live(bic.name, bic.methods)

                # Collect math types referenced by method args / returns
                refs =
                    ms.fold([], |acc, md| {
                        acc1 =
                            match md.arguments {
                                Ok(args) =>
                                    args.fold(acc, |a2, arg|
                                        collect_type_refs(a2, bic.name, c_to_roc_type(arg.type))
                                    )
                                _ => acc
                            }
                        ret_t = c_to_roc_type(method_return_type_str(md))
                        collect_type_refs(acc1, bic.name, ret_t)
                    })

                math_refs =
                    refs.fold([], |acc, t| {
                        if ExtensionApiRenderer.is_struct_builtin(t) and t != bic.name and !(List.contains(acc, t)) {
                            List.append(acc, t)
                        } else {
                            acc
                        }
                    })

                peer_imports =
                    if List.is_empty(math_refs) {
                        ""
                    } else {
                        Str.concat(
                            Str.join_with(math_refs.map(|t| "import ${t}"), "\n"),
                            "\n",
                        )
                    }

                \\# ${bic.name} methods → Host (callBuiltin)
                \\import ../../Host
                \\import ${bic.name}
                \\${peer_imports}
                \\${bic.name}Methods := [].{
                \\${body}
                \\}
            }
            _ => ""
        }
    }

    is_struct_builtin : Str -> Bool
    is_struct_builtin = |name| {
        match name {
            "Vector2" | "Vector2i" | "Vector3" | "Vector3i" | "Vector4" | "Vector4i"
            | "Rect2" | "Rect2i" | "AABB"
            | "Transform2D" | "Transform3D" | "Basis" | "Projection"
            | "Plane" | "Quaternion" | "Color" => Bool.True
            _ => Bool.False
        }
    }

    math_type_names : List(Str)
    math_type_names = [
        "Vector2",
        "Vector2i",
        "Vector3",
        "Vector3i",
        "Vector4",
        "Vector4i",
        "Rect2",
        "Rect2i",
        "AABB",
        "Transform2D",
        "Transform3D",
        "Basis",
        "Projection",
        "Plane",
        "Quaternion",
        "Color",
    ]

}


host_facade_decls : Str
host_facade_decls =
    \\    # --- platform façade (host.zig MVP) ---
    \\    current_engine! : () => U8  # TODO:
    \\    current_target! : () => U8  # TODO:
    \\    engine_runtime_ok! : () => U8
    \\    register_class! : Str, Str => U32
    \\    print_error! : Str => {}
    \\    print_warning! : Str => {}
    \\    instance_id! : () => U64
    \\    instance_class_id! : () => U32
    \\    user_slot_count! : () => U64
    \\    user_slot_get! : U64 => U64
    \\    user_slot_set! : U64, U64 => {}
    \\    user_slot_get_f32! : U64 => F32
    \\    user_slot_set_f32! : U64, F32 => {}





target : ExtensionApi -> Str
target = |_eapi| {
    \\## The CpuArch Target

}




math_type_peer_imports : Str -> Str
math_type_peer_imports = |name| {
    match name {
        "Rect2" => "import Vector2\n\n"
        "Rect2i" => "import Vector2i\n\n"
        "AABB" => "import Vector3\n\n"
        "Plane" => "import Vector3\n\n"
        "Basis" => "import Vector3\n\n"
        "Transform2D" => "import Vector2\n\n"
        "Transform3D" => "import Basis\nimport Vector3\n\n"
        "Projection" => "import Vector4\n\n"
        _ => ""
    }
}





host_facade_symbols : List(Str)
host_facade_symbols = [
    "current_engine", # TODO:
    "current_target", # TODO:
    "engine_runtime_ok",
    "register_class",
    "print_error",
    "print_warning",
    "instance_id",
    "instance_class_id",
    "user_slot_count",
    "user_slot_get",
    "user_slot_set",
    "user_slot_get_f32",
    "user_slot_set_f32",
]



# =============================================================================
# Naming
# =============================================================================





roc_type_ident : Str -> Str
roc_type_ident = |s|
    s.replace_each("::", "_").replace_each(".", "_").replace_each(" ", "_").replace_each("/", "_")

to_value_name : Str -> Str
to_value_name = |s| s.with_ascii_lowercased()

roc_fn_name : Str -> Str
roc_fn_name = |name| {
    n =
        name
            .replace_each(" ", "_")
            .replace_each(".", "_")
            .replace_each(":", "_")
            .replace_each("/", "_")
            .replace_each("-", "_")
            .replace_each("==", "eq")
            .replace_each("!=", "neq")
            .replace_each("<=", "lte")
            .replace_each(">=", "gte")
            .replace_each("<", "lt")
            .replace_each(">", "gt")
            .replace_each("*", "mul")
            .replace_each("+", "add")
            .replace_each("%", "mod")
            .replace_each("^", "xor")
            .replace_each("|", "bitor")
            .replace_each("&", "bitand")
            .replace_each("!", "not")
    if n == "" {
        "op"
    } else {
        n
    }
}

host_symbol : Str -> Str
host_symbol = |s| s.with_ascii_lowercased()

host_method_symbol : Str, Str, U64 -> Str
host_method_symbol = |owner, name, hash|
    host_symbol("${roc_fn_name(owner)}_${roc_fn_name(name)}_${hash.to_str()}")

host_singleton_symbol : Str -> Str
host_singleton_symbol = |name|
    host_symbol("get_singleton_${roc_fn_name(name)}")

host_util_symbol : Str, U64 -> Str
host_util_symbol = |name, hash|
    host_symbol("util_${roc_fn_name(name)}_${hash.to_str()}")

host_linker_symbol : Str -> Str
host_linker_symbol = |sym| "godot_roc_${sym}"

hosted_entry : Str -> Str
hosted_entry = |sym|
    \\        "${host_linker_symbol(sym)}": Host.${sym}!,

# =============================================================================
# Type mapping
# =============================================================================



canonical_roc_fields : Str -> Str
canonical_roc_fields = |name| {
    match name {
        "Vector2" => "    x : F32,\n    y : F32"
        "Vector2i" => "    x : I32,\n    y : I32"
        "Vector3" => "    x : F32,\n    y : F32,\n    z : F32"
        "Vector3i" => "    x : I32,\n    y : I32,\n    z : I32"
        "Vector4" => "    x : F32,\n    y : F32,\n    z : F32,\n    w : F32"
        "Vector4i" => "    x : I32,\n    y : I32,\n    z : I32,\n    w : I32"
        "Quaternion" => "    x : F32,\n    y : F32,\n    z : F32,\n    w : F32"
        "Color" => "    r : F32,\n    g : F32,\n    b : F32,\n    a : F32"
        "Rect2" => "    position : Vector2,\n    size : Vector2"
        "Rect2i" => "    position : Vector2i,\n    size : Vector2i"
        "AABB" => "    position : Vector3,\n    size : Vector3"
        "Plane" => "    normal : Vector3,\n    d : F32"
        "Basis" => "    rows : List(Vector3)"
        "Transform2D" => "    x : Vector2,\n    y : Vector2,\n    origin : Vector2"
        "Transform3D" => "    basis : Basis,\n    origin : Vector3"
        "Projection" => "    columns : List(Vector4)"
        _ => "    ptr : U64"
    }
}

canonical_zig_fields : Str -> Str
canonical_zig_fields = |name| {
    match name {
        "Vector2" => "    x: f32,\n    y: f32,"
        "Vector2i" => "    x: i32,\n    y: i32,"
        "Vector3" => "    x: f32,\n    y: f32,\n    z: f32,"
        "Vector3i" => "    x: i32,\n    y: i32,\n    z: i32,"
        "Vector4" => "    x: f32,\n    y: f32,\n    z: f32,\n    w: f32,"
        "Vector4i" => "    x: i32,\n    y: i32,\n    z: i32,\n    w: i32,"
        "Quaternion" => "    x: f32,\n    y: f32,\n    z: f32,\n    w: f32,"
        "Color" => "    r: f32,\n    g: f32,\n    b: f32,\n    a: f32,"
        "Rect2" => "    position: Vector2,\n    size: Vector2,"
        "Rect2i" => "    position: Vector2i,\n    size: Vector2i,"
        "AABB" => "    position: Vector3,\n    size: Vector3,"
        "Plane" => "    normal: Vector3,\n    d: f32,"
        "Basis" => "    rows: [3]Vector3,"
        "Transform2D" => "    x: Vector2,\n    y: Vector2,\n    origin: Vector2,"
        "Transform3D" => "    basis: Basis,\n    origin: Vector3,"
        "Projection" => "    columns: [4]Vector4,"
        _ => "    // TODO: layout for ${name}"
    }
}

strip_enum_bitfield_to_int : Str -> Str
strip_enum_bitfield_to_int = |str| {
    if str.starts_with("enum::") {
        "I64"
    } else if str.starts_with("bitfield::") {
        "I64"
    } else {
        str
    }
}

c_to_host_type : Str -> Str
c_to_host_type = |str| {
    cleaned = strip_enum_bitfield_to_int(str)
    match cleaned {
        "int" => "I64"
        "float" => "F64"
        "double" => "F64"
        "bool" => "U8"   # was Bool — must match Zig u8 / GDExtensionBool (TODO: consider using an alias...)
        "void" => "{}"
        "String" => "Str"
        "StringName" => "Str"
        "NodePath" => "Str"
        "Error" => "I64"
        "Variant" => "U64"
        "RID" => "U64"
        "Callable" => "U64"
        "Signal" => "U64"
        "Dictionary" => "U64"
        "Array" => "U64"
        other if other.starts_with("typedarray::") => "U64"
        other if other.starts_with("packed") => "U64"
        other if ExtensionApiRenderer.is_struct_builtin(other) => other
        _ => "U64"
    }
}

c_to_roc_type : Str -> Str
c_to_roc_type = |str| {
    cleaned =
        if str.starts_with("enum::") {
            roc_type_ident(str.drop_prefix("enum::"))
        } else if str.starts_with("bitfield::") {
            roc_type_ident(str.drop_prefix("bitfield::"))
        } else {
            str
        }
    match cleaned {
        "int" => "I64"
        "float" => "F64"
        "double" => "F64"
        "bool" => "Bool"
        "void" => "{}"
        "String" => "Str"
        "StringName" => "Str"
        "NodePath" => "Str"
        "Error" => "I64"
        "Variant" => "U64"
        "RID" => "U64"
        "Callable" => "U64"
        "Signal" => "U64"
        "Dictionary" => "U64"
        "Array" => "U64"
        "Crypto" => "GodotCrypto"
        "Range" => "GodotRange"
        other if other.starts_with("typedarray::") => "U64"
        other if other.starts_with("packed") => "U64"
        other if ExtensionApiRenderer.is_struct_builtin(other) => other
        other => ExtensionApiRenderer.builtin_module_name(other)
    }
}

c_to_zig_type : Str -> Str
c_to_zig_type = |str| {
    cleaned =
        if str.starts_with("enum::") or str.starts_with("bitfield::") {
            "i64"
        } else {
            str
        }
    match cleaned {
        "bool" => "u8"
        "int" => "i64"
        "float" => "f64"
        "double" => "f64"
        "void" => "void"
        "String" => "u64"
        "StringName" => "u64"
        "NodePath" => "u64"
        "Error" => "i64"
        "Variant" => "u64"
        "RID" => "u64"
        "Callable" => "u64"
        "Signal" => "u64"
        "Dictionary" => "u64"
        "Array" => "u64"
        other if other.starts_with("typedarray::") => "u64"
        other if other.starts_with("packed") => "u64"
        other if ExtensionApiRenderer.is_struct_builtin(other) => other
        _ => "u64"
    }
}

c_to_zig_ret : Str -> Str
c_to_zig_ret = |str| c_to_zig_type(str)

c_to_zig_ret_from_try : Try(Str, [Missing]) -> Str
c_to_zig_ret_from_try = |maybe|
    match maybe {
        Ok(t) => c_to_zig_ret(t)
        _ => "void"
    }

c_to_zig_arg : Str -> Str
c_to_zig_arg = |str| {
    cleaned =
        if str.starts_with("enum::") or str.starts_with("bitfield::") {
            "i64"
        } else {
            str
        }
    match cleaned {
        "bool" => "u8"
        "int" => "i64"
        "float" => "f64"
        "double" => "f64"
        "void" => "void"
        "String" | "StringName" | "NodePath" => "abi.RocStr"
        "Error" => "i64"
        "Variant" | "RID" | "Callable" | "Signal" | "Dictionary" | "Array" => "u64"
        other if other.starts_with("typedarray::") => "u64"
        other if other.starts_with("packed") => "u64"
        other if ExtensionApiRenderer.is_struct_builtin(other) => other
        _ => "u64"
    }
}

is_string_godot_type : Str -> Bool
is_string_godot_type = |t| {
    t == "String" or t == "StringName" or t == "NodePath"
}

## Zig body fragment: log stub, then default return.
zig_stub_body : Str, Str -> Str
zig_stub_body = |message, zig_ty| {
    ret_line = zig_default_ret(zig_ty)
    # ret_line is "" for void, or "return 0;" / "return std.mem.zeroes(...);" etc.
    if ret_line == "" {
        \\    gde_call.godotRocCtx().iface.print_error("[godot-roc STUB] ${message}", "this_stub", @src().file, @src().line, 0);
    } else {
        \\    gde_call.godotRocCtx().iface.print_error("[godot-roc STUB] ${message}", "this_stub", @src().file, @src().line, 0);
        \\    ${ret_line}
    }
}

zig_default_ret : Str -> Str
zig_default_ret = |zig_ty| {
    match zig_ty {
        "void" => ""
        "u8" => "return 0;"
        "i64" => "return 0;"
        "f64" => "return 0;"
        "u64" => "return 0;"
        "Vector2" | "Vector2i" | "Vector3" | "Vector3i" | "Vector4" | "Vector4i"
        | "Rect2" | "Rect2i" | "AABB"
        | "Transform2D" | "Transform3D" | "Basis" | "Projection"
        | "Plane" | "Quaternion" | "Color" =>
            "return std.mem.zeroes(${zig_ty});"
        _ => "return undefined;"
    }
}

## Types allowed in auto-wired utility (gde_call.callUtility) bodies
util_c_type_is_simple : Str -> Bool
util_c_type_is_simple = |str| {
    cleaned =
        if str.starts_with("enum::") or str.starts_with("bitfield::") {
            "int"
        } else {
            str
        }
    match cleaned {
        "bool" | "int" | "float" | "double" | "void" => Bool.True
        _ => Bool.False
    }
}

method_c_type_is_wireable : Str -> Bool
method_c_type_is_wireable = |str| {
    method_c_type_is_simple(str)
}

method_c_type_is_simple : Str -> Bool
method_c_type_is_simple = |str| {
    cleaned =
        if str.starts_with("enum::") or str.starts_with("bitfield::") {
            "int"
        } else {
            str
        }
    match cleaned {
        "bool" | "int" | "float" | "double" | "void" => Bool.True
        "String" | "StringName" | "NodePath" => Bool.True
        other if ExtensionApiRenderer.is_struct_builtin(other) => Bool.True
        _ => Bool.False
    }
}

method_return_type_str : MethodDef -> Str
method_return_type_str = |md|
    match md.return_type {
        Ok(t) => t
        _ =>
            match md.return_value {
                Ok(rv) => rv.type
                _ => "void"
            }
    }

method_is_simple_ptrcall : MethodDef -> Bool
method_is_simple_ptrcall = |md| {
    if md.is_vararg {
        Bool.False
    } else {
        ret_ok = method_c_type_is_wireable(method_return_type_str(md))
        args_ok =
            match md.arguments {
                Ok(args) =>
                    args.fold(Bool.True, |acc, a|
                        if acc and method_c_type_is_wireable(a.type) {
                            Bool.True
                        } else {
                            Bool.False
                        }
                    )
                _ => Bool.True
            }
        ret_ok and args_ok
    }
}

zig_method_arg_local : Str -> Str
zig_method_arg_local = |name| {
    n = roc_fn_name(name)
    if n == "" {
        "arg"
    } else {
        "a_${n}"
    }
}

## Named params (needed so we can take addresses for ptrcall).
zig_method_params_named : MethodDef -> Str
zig_method_params_named = |md|
    match md.arguments {
        Ok(args) if !(args.is_empty()) =>
            Str.join_with(
                args.map(|a| {
                    loc = zig_method_arg_local(a.name)
                    \\${loc}: ${c_to_zig_arg(a.type)}
                }),
                ", ",
            )
        _ => ""
    }

zig_method_params_named_for : Str, MethodDef -> Str
zig_method_params_named_for = |owner, md| {
    explicit = zig_method_params_named(md)
    if md.is_static or !(ExtensionApiRenderer.is_struct_builtin(owner)) {
        explicit
    } else {
        self_ty = c_to_zig_type(owner)
        if explicit == "" {
            "self_val: ${self_ty}"
        } else {
            "self_val: ${self_ty}, ${explicit}"
        }
    }
}

zig_ptrcall_args_setup : MethodDef -> { locals : Str, args_array : Str, args_ptr : Str }
zig_ptrcall_args_setup = |md| {
    arg_list = match md.arguments { Ok(a) => a _ => [] }
    if List.is_empty(arg_list) {
        {
            locals: "",
            args_array: "",
            args_ptr: "null",
        }
    } else {
        locals =
            Str.concat(
                Str.join_with(
                    arg_list.map(|a| {
                        loc = zig_method_arg_local(a.name)
                        if is_string_godot_type(a.type) {
                            \\    var ${loc}_owned = ${loc};
                            \\    defer ${loc}_owned.decref(gde_call.rocHost());
                            \\    var ${loc}_buf: [256]u8 = undefined;
                            \\    const ${loc}_z = gde_call.copyRocStrToBuf(${loc}_owned, &${loc}_buf);
                            \\    var ${loc}_sn = gde_call.makeStringName(gde_call.godotRocCtx(), ${loc}_z);
                            \\    defer gde_call.destroyStringName(gde_call.godotRocCtx(), &${loc}_sn);
                        } else if is_object_ptr_godot_type(a.type) {
                            \\    var ${loc}_: ?*anyopaque = @ptrFromInt(@as(usize, @bitCast(${loc})));
                        } else {
                            # bool / int / float / math structs — pass address of value
                            \\    var ${loc}_ = ${loc};
                        }
                    }),
                    "\n",
                ),
                "\n",
            )
        ptrs =
            Str.join_with(
                arg_list.map(|a| {
                    loc = zig_method_arg_local(a.name)
                    if is_string_godot_type(a.type) {
                        \\        @ptrCast(&${loc}_sn),
                    } else {
                        \\        @ptrCast(&${loc}_),
                    }
                }),
                "\n",
            )
        {
            locals,
            args_array:
                \\    const args = [_]baseline_gde_if.GDExtensionConstTypePtr{
                \\${ptrs}
                \\    };
                \\
            ,
            args_ptr: "&args",
        }
    }
}

method_hash_key : Str, MethodDef -> Str
method_hash_key = |owner, md|
    "${zig_hash_ident(owner)}_${zig_hash_ident(md.name)}"

util_is_simple : UtilityFunction -> Bool
util_is_simple = |uf| {
    if uf.is_vararg {
        Bool.False
    } else {
        ret_ok =
            match uf.return_type {
                Ok(rt) => util_c_type_is_simple(rt)
                _ => Bool.True
            }
        args_ok =
            match uf.arguments {
                Ok(args) =>
                    args.fold(Bool.True, |acc, a|
                        if acc and util_c_type_is_simple(a.type) {
                            Bool.True
                        } else {
                            Bool.False
                        }
                    )
                _ => Bool.True
            }
        ret_ok and args_ok
    }
}

zig_util_arg_local : Str -> Str
zig_util_arg_local = |name| {
    n = roc_fn_name(name)
    if n == "" {
        "arg"
    } else {
        "a_${n}"
    }
}

# =============================================================================
# Host symbols
# =============================================================================

all_host_symbols : ExtensionApi -> List(Str)
all_host_symbols = |eapi| {

    sings = eapi.singletons.map(|s| host_singleton_symbol(s.name))
    utils = eapi.utility_functions.map(|uf| host_util_symbol(uf.name, u64_or_0(uf.hash)))

    builtin_ms =
        eapi.builtin_classes.fold([], |acc, bic| {
            match bic.methods {
                Ok(ms) => List.concat(acc, ms.map(|md| host_method_symbol(bic.name, md.name, u64_or_0(md.hash))))
                _ => acc
            }
        })

    class_ms =
        eapi.classes.fold([], |acc, cls| {
            match cls.methods {
                Ok(ms) => List.concat(acc, ms.map(|md| host_method_symbol(cls.name, md.name, u64_or_0(md.hash))))
                _ => acc
            }
        })

    List.concat(
        host_facade_symbols,
        List.concat(sings, List.concat(utils, List.concat(builtin_ms, class_ms))),
    )
}

# =============================================================================
# Platform root
# =============================================================================





# =============================================================================
# Method helpers
# =============================================================================

method_arg_types_host_for : Str, MethodDef -> Str
method_arg_types_host_for = |owner, md| {
    explicit =
        match md.arguments {
            Ok(args) if !(args.is_empty()) =>
                Str.join_with(args.map(|a| c_to_host_type(a.type)), ", ")
            _ => ""
        }
    if md.is_static {
        if explicit == "" {
            "()"
        } else {
            explicit
        }
    } else if ExtensionApiRenderer.is_struct_builtin(owner) {
        self_ty = c_to_host_type(owner)
        if explicit == "" {
            self_ty
        } else {
            "${self_ty}, ${explicit}"
        }
    } else {
        if explicit == "" {
            "()"
        } else {
            explicit
        }
    }
}

method_arg_types_host : MethodDef -> Str
method_arg_types_host = |md|
    match md.arguments {
        Ok(args) if !(args.is_empty()) =>
            Str.join_with(args.map(|a| c_to_host_type(a.type)), ", ")
        _ => "()"
    }

method_return_type_host : MethodDef -> Str
method_return_type_host = |md|
    match md.return_type {
        Ok(rt) => c_to_host_type(rt)
        _ =>
            match md.return_value {
                Ok(rv) => c_to_host_type(rv.type)
                _ => "{}"
            }
    }

method_def_live : Str, MethodDef -> Str
method_def_live = |owner, md| {
    fn = roc_fn_name(md.name)
    sym = host_method_symbol(owner, md.name, u64_or_0(md.hash))
    args_ty = method_arg_types_host_for(owner, md)
    ret = method_return_type_host(md)
    \\    ${fn}! : ${args_ty} => ${ret}
    \\    ${fn}! = Host.${sym}!
}

property_def_comment : PropertyDef -> Str
property_def_comment = |p| {
    ty = c_to_host_type(p.type)
    g = match p.getter { Ok(x) => x _ => "(none)" }
    s = match p.setter { Ok(x) => x _ => "(none)" }
    \\    # property ${p.name} : ${ty}  getter=${g} setter=${s}
}

methods_block_live : Str, Try(List(MethodDef), [Missing]) -> Str
methods_block_live = |owner, maybe|
    match maybe {
        Ok(ms) => Str.join_with(ms.map(|md| method_def_live(owner, md)), "\n")
        _ => ""
    }

properties_block_comments : Try(List(PropertyDef), [Missing]) -> Str
properties_block_comments = |maybe|
    match maybe {
        Ok(ps) => Str.join_with(ps.map(property_def_comment), "\n")
        _ => ""
    }

enum_def_line : EnumDef -> Str
enum_def_line = |e| {
    ename = roc_type_ident(e.name)
    values = Str.join_with(e.values.map(|v| v.name), ", ")
    \\    ${ename} : [${values}]
}

enums_block : Try(List(EnumDef), [Missing]) -> Str
enums_block = |maybe|
    match maybe {
        Ok(ens) => Str.join_with(ens.map(enum_def_line), "\n")
        _ => ""
    }

signal_def_line : SignalDef -> Str
signal_def_line = |sig| {
    args =
        match sig.arguments {
            Ok(a) if !(a.is_empty()) =>
                Str.join_with(a.map(|x| "${x.name} : ${c_to_host_type(x.type)}"), ", ")
            _ => "()"
        }
    \\    # signal ${sig.name} : ${args}
}

signals_block : Try(List(SignalDef), [Missing]) -> Str
signals_block = |maybe|
    match maybe {
        Ok(ss) => Str.join_with(ss.map(signal_def_line), "\n")
        _ => ""
    }

# =============================================================================
# Host.roc
# =============================================================================

host_entry : Str, Str, Str -> Str
host_entry = |sym, args_ty, ret_ty|
    \\    ${sym}! : ${args_ty} => ${ret_ty}



# =============================================================================
# Meta modules
# =============================================================================



# =============================================================================
# Builtin / class / singleton
# =============================================================================

collect_type_refs : List(Str), Str, Str -> List(Str)
collect_type_refs = |acc, type_name, t| {
    is_prim =
        match t {
            "I32" | "I64" | "F32" | "F64" | "Bool" | "{}" | "U64" | "Str" => Bool.True
            _ => Bool.False
        }
    if is_prim or t == type_name {
        acc
    } else if List.contains(acc, t) {
        acc
    } else {
        List.append(acc, t)
    }
}





# =============================================================================
# Zig ABI
# =============================================================================

member_to_roc_field_type : Str -> Str
member_to_roc_field_type = |str| {
    match str {
        "float" => "F32"
        "double" => "F64"
        "int" => "I32"
        other => c_to_roc_type(other)
    }
}

member_to_zig_field_type : Str -> Str
member_to_zig_field_type = |str| {
    match str {
        "float" => "f32"
        "double" => "f64"
        "int" => "i32"
        "bool" => "u8"
        other if ExtensionApiRenderer.is_struct_builtin(other) => other
        _ => c_to_zig_type(str)
    }
}

zig_extern_struct_for_builtin : BuiltinClass -> Str
zig_extern_struct_for_builtin = |bic| {
    name = bic.name
    if !(ExtensionApiRenderer.is_struct_builtin(name)) {
        ""
    } else {
        fields = canonical_zig_fields(name)
        \\
        \\/// Godot builtin ${name} (value type, canonical C ABI layout)
        \\pub const ${name} = extern struct {
        \\${fields}
        \\};
    }
}

zig_all_extern_structs : ExtensionApi -> Str
zig_all_extern_structs = |eapi|
    Str.join_with(
        eapi.builtin_classes.map(zig_extern_struct_for_builtin),
        "\n",
    )

zig_hash_ident : Str -> Str
zig_hash_ident = |s|
    s.replace_each(" ", "_")
        .replace_each(".", "_")
        .replace_each(":", "_")
        .replace_each("/", "_")
        .replace_each("-", "_")

zig_method_hash_entry : Str, MethodDef -> Str
zig_method_hash_entry = |owner, md| {
    key = "${zig_hash_ident(owner)}_${zig_hash_ident(md.name)}"
    \\    pub const ${key}: i64 = ${u64_or_0(md.hash).to_str()};
}

zig_hashes_struct : ExtensionApi -> Str
zig_hashes_struct = |eapi| {
    util_lines =
        Str.join_with(
            eapi.utility_functions.map(|uf| {
                key = "util_${zig_hash_ident(uf.name)}"
                \\    pub const ${key}: i64 = ${u64_or_0(uf.hash).to_str()};
            }),
            "\n",
        )

    builtin_lines =
        Str.join_with(
            eapi.builtin_classes.map(|bic| {
                match bic.methods {
                    Ok(ms) =>
                        Str.join_with(ms.map(|md| zig_method_hash_entry(bic.name, md)), "\n")
                    _ => ""
                }
            }),
            "\n",
        )

    class_lines =
        Str.join_with(
            eapi.classes.map(|cls| {
                match cls.methods {
                    Ok(ms) =>
                        Str.join_with(ms.map(|md| zig_method_hash_entry(cls.name, md)), "\n")
                    _ => ""
                }
            }),
            "\n",
        )

    \\
    \\pub const hashes = struct {
    \\${util_lines}
    \\${builtin_lines}
    \\${class_lines}
    \\};
}

zig_method_params : MethodDef -> Str
zig_method_params = |md|
    match md.arguments {
        Ok(args) if !(args.is_empty()) =>
            Str.join_with(
                args.map(|a| {
                    \\_: ${c_to_zig_arg(a.type)}
                }),
                ", ",
            )
        _ => ""
    }

zig_method_params_for : Str, MethodDef -> Str
zig_method_params_for = |owner, md| {
    explicit = zig_method_params(md)
    if md.is_static or !(ExtensionApiRenderer.is_struct_builtin(owner)) {
        explicit
    } else {
        self_ty = c_to_zig_type(owner)
        if explicit == "" {
            "_: ${self_ty}"
        } else {
            "_: ${self_ty}, ${explicit}"
        }
    }
}

zig_method_return : MethodDef -> Str
zig_method_return = |md|
    match md.return_type {
        Ok(t) => c_to_zig_ret(t)
        _ =>
            match md.return_value {
                Ok(rv) => c_to_zig_ret(rv.type)
                _ => "void"
            }
    }

zig_export_method : ExtensionApi, Str, MethodDef -> Str
zig_export_method = |eapi, owner, md| {
    sym = host_method_symbol(owner, md.name, u64_or_0(md.hash))
    ret = zig_method_return(md)
    hkey = method_hash_key(owner, md)
    is_builtin = ExtensionApiRenderer.is_struct_builtin(owner)
    arg_list = match md.arguments { Ok(a) => a _ => [] }
    n_args = arg_list.len().to_str()

    # singleton = is_singleton_name(eapi, owner) # TODO: use this or not??

    if !(method_is_simple_ptrcall(md)) {
        params = zig_method_params_for(owner, md)
        msg = "${owner}.${md.name} hash=${u64_or_0(md.hash).to_str()} (non-simple / not wired)"
        body = zig_stub_body(msg, ret)
        \\
        \\/// ${owner}.${md.name} hash=${u64_or_0(md.hash).to_str()} (stub — non-simple)
        \\export fn godot_roc_${sym}(${params}) callconv(.c) ${ret} {
        \\${body}
        \\}
    } else if is_builtin {
        params = zig_method_params_named_for(owner, md)
        setup = zig_ptrcall_args_setup(md)

        # Non-static: first param is self_val (by value). Copy to local and pass &self_val_.
        base_setup =
            if md.is_static {
                \\    const base_ptr: ?*anyopaque = null;
            } else {
                \\    var self_val_ = self_val;
                \\    const base_ptr: ?*anyopaque = @ptrCast(&self_val_);
            }

        if ret == "void" {
            \\
            \\/// ${owner}.${md.name} hash=${u64_or_0(md.hash).to_str()} (callBuiltin)
            \\export fn godot_roc_${sym}(${params}) callconv(.c) void {
            \\${base_setup}
            \\${setup.locals}${setup.args_array}    _ = gde_call.callBuiltin(
            \\        gde_call.godotRocCtx(),
            \\        "${owner}",
            \\        "${md.name}",
            \\        hashes.${hkey},
            \\        base_ptr,
            \\        ${setup.args_ptr},
            \\        ${n_args},
            \\        null,
            \\    );
            \\}
        } else {
            \\
            \\/// ${owner}.${md.name} hash=${u64_or_0(md.hash).to_str()} (callBuiltin)
            \\export fn godot_roc_${sym}(${params}) callconv(.c) ${ret} {
            \\${base_setup}
            \\${setup.locals}${setup.args_array}    var ret_val: ${ret} = std.mem.zeroes(${ret});
            \\    _ = gde_call.callBuiltin(
            \\        gde_call.godotRocCtx(),
            \\        "${owner}",
            \\        "${md.name}",
            \\        hashes.${hkey},
            \\        base_ptr,
            \\        ${setup.args_ptr},
            \\        ${n_args},
            \\        @ptrCast(&ret_val),
            \\    );
            \\    return ret_val;
            \\}
        }
        } else {
            params = zig_method_params_named_for(owner, md)
            setup = zig_ptrcall_args_setup(md)
            singleton = is_singleton_name(eapi, owner)

            if ret == "void" {
                obj_setup =
                    if md.is_static {
                        \\    const obj: ?*anyopaque = null;
                    } else if singleton {
                        \\    const obj = gde_call.getSingleton(gde_call.godotRocCtx(), "${owner}") orelse return;
                    } else {
                        \\    const obj = g_godot_roc_current orelse return;
                    }
                \\
                \\/// ${owner}.${md.name} hash=${u64_or_0(md.hash).to_str()} (callInstance)
                \\export fn godot_roc_${sym}(${params}) callconv(.c) void {
                \\${obj_setup}
                \\${setup.locals}${setup.args_array}    _ = gde_call.callInstance(
                \\        gde_call.godotRocCtx(),
                \\        "${owner}",
                \\        "${md.name}",
                \\        hashes.${hkey},
                \\        obj,
                \\        ${setup.args_ptr},
                \\        null,
                \\    );
                \\}
            } else {
                obj_setup =
                    if md.is_static {
                        \\    const obj: ?*anyopaque = null;
                    } else if singleton {
                        \\    const obj = gde_call.getSingleton(gde_call.godotRocCtx(), "${owner}") orelse return std.mem.zeroes(${ret});
                    } else {
                        \\    const obj = g_godot_roc_current orelse return std.mem.zeroes(${ret});
                    }
                \\
                \\/// ${owner}.${md.name} hash=${u64_or_0(md.hash).to_str()} (callInstance)
                \\export fn godot_roc_${sym}(${params}) callconv(.c) ${ret} {
                \\${obj_setup}
                \\${setup.locals}${setup.args_array}    var ret_val: ${ret} = std.mem.zeroes(${ret});
                \\    _ = gde_call.callInstance(
                \\        gde_call.godotRocCtx(),
                \\        "${owner}",
                \\        "${md.name}",
                \\        hashes.${hkey},
                \\        obj,
                \\        ${setup.args_ptr},
                \\        @ptrCast(&ret_val),
                \\    );
                \\    return ret_val;
                \\}
            }
        }
}

## Simple utils → gde_call.callUtility; others → stubs
zig_export_util : UtilityFunction -> Str
zig_export_util = |uf| {
    sym = host_util_symbol(uf.name, u64_or_0(uf.hash))
    ret = c_to_zig_ret_from_try(uf.return_type)
    hash_key = "util_${zig_hash_ident(uf.name)}"
    arg_list = match uf.arguments { Ok(a) => a _ => [] }
    n_args = arg_list.len().to_str()

    if !(util_is_simple(uf)) {
        params =
            if List.is_empty(arg_list) {
                ""
            } else {
                Str.join_with(
                    arg_list.map(|a| {
                        \\_: ${c_to_zig_arg(a.type)}
                    }),
                    ", ",
                )
            }
        msg = "utility ${uf.name} hash=${u64_or_0(uf.hash).to_str()} (non-simple / vararg / not wired)"
        body = zig_stub_body(msg, ret)
        \\
        \\/// utility ${uf.name} (stub — non-simple / vararg)
        \\export fn godot_roc_${sym}(${params}) callconv(.c) ${ret} {
        \\${body}
        \\}
    } else {
        params =
            if List.is_empty(arg_list) {
                ""
            } else {
                Str.join_with(
                    arg_list.map(|a| {
                        loc = zig_util_arg_local(a.name)
                        \\${loc}: ${c_to_zig_arg(a.type)}
                    }),
                    ", ",
                )
            }

        locals =
            if List.is_empty(arg_list) {
                ""
            } else {
                Str.concat(
                    Str.join_with(
                        arg_list.map(|a| {
                            loc = zig_util_arg_local(a.name)
                            \\    var ${loc}_ = ${loc};
                        }),
                        "\n",
                    ),
                    "\n",
                )
            }

        args_array =
            if List.is_empty(arg_list) {
                \\    const args_ptr: ?[*]const baseline_gde_if.GDExtensionConstTypePtr = null;
            } else {
                ptrs =
                    Str.join_with(
                        arg_list.map(|a| {
                            loc = zig_util_arg_local(a.name)
                            \\        @ptrCast(&${loc}_),
                        }),
                        "\n",
                    )
                \\    const args = [_]baseline_gde_if.GDExtensionConstTypePtr{
                \\${ptrs}
                \\    };
                \\    const args_ptr: ?[*]const baseline_gde_if.GDExtensionConstTypePtr = &args;
            }

        body_ret =
            if ret == "void" {
                \\    _ = gde_call.callUtility(
                \\        gde_call.godotRocCtx(),
                \\        "${uf.name}",
                \\        hashes.${hash_key},
                \\        args_ptr,
                \\        ${n_args},
                \\        null,
                \\    );
            } else {
                \\    var ret_val: ${ret} = std.mem.zeroes(${ret});
                \\    _ = gde_call.callUtility(
                \\        gde_call.godotRocCtx(),
                \\        "${uf.name}",
                \\        hashes.${hash_key},
                \\        args_ptr,
                \\        ${n_args},
                \\        @ptrCast(&ret_val),
                \\    );
                \\    return ret_val;
            }

        \\
        \\/// utility ${uf.name} hash=${u64_or_0(uf.hash).to_str()} (gde_call)
        \\export fn godot_roc_${sym}(${params}) callconv(.c) ${ret} {
        \\${locals}${args_array}
        \\${body_ret}
        \\}
    }
}

zig_export_singleton : Singleton -> Str
zig_export_singleton = |s| {
    sym = host_singleton_symbol(s.name)
    \\
    \\/// singleton ${s.name}
    \\export fn godot_roc_${sym}() callconv(.c) u64 {
    \\    const obj = gde_call.getSingleton(gde_call.godotRocCtx(), "${s.name}") orelse return 0;
    \\    return @intFromPtr(obj);
    \\}
}

zig_facade_note : Str
zig_facade_note =
    \\
    \\// Platform façade symbols (register_class, print_error, set_velocity, …)
    \\// are implemented in host.zig — do not duplicate export fns here.
    \\


is_singleton_name : ExtensionApi, Str -> Bool
is_singleton_name = |eapi, name| {
    eapi.singletons.fold(Bool.False, |found, s|
        if found or s.name == name {
            Bool.True
        } else {
            Bool.False
        }
    )
}

## True when Zig param is u64 used as an Object / RID / opaque handle for ptrcall.
is_object_ptr_godot_type : Str -> Bool
is_object_ptr_godot_type = |t| {
    cleaned =
        if t.starts_with("enum::") or t.starts_with("bitfield::") {
            "int"
        } else {
            t
        }
    if is_string_godot_type(cleaned) {
        Bool.False
    } else if ExtensionApiRenderer.is_struct_builtin(cleaned) {
        Bool.False
    } else {
        match cleaned {
            "bool" | "int" | "float" | "double" | "void" | "Error" => Bool.False
            "Variant" | "RID" | "Callable" | "Signal" | "Dictionary" | "Array" => Bool.False
            other if other.starts_with("typedarray::") => Bool.False
            other if other.starts_with("packed") => Bool.False
            # Named classes / Object → Zig u64 pointer handle
            "Object" | "Node" | "RefCounted" => Bool.True
            _ => Bool.True
        }
    }
}

render_targets_block : List(CpuArchOS), List(CpuArchOS) -> Str
render_targets_block = |selected_targets, all_targets| {
    if selected_targets.len() == 0 {
        crash "render_targets_block: got=${Str.join_with(selected_targets.map(|t| t.to_name()), ",")}, expected one or more=${Str.join_with(all_targets.map(|t| t.to_name()), ",")}"
    }
    \\    targets: {
    \\        inputs_dir: "targets/",
    \\        ${Str.join_with(selected_targets.map(to_roc_entry), "\n        ")}
    \\    }
}

to_roc_entry : CpuArchOS -> Str
to_roc_entry = |cpu_arch_os| {
    match cpu_arch_os {
        CpuArchOS.Wasm32 =>      \\wasm32: { inputs: [ "libhost.o.wasm", app ], output: Archive, exports: [ "gdextension_roc_init" ], },
        CpuArchOS.X64musl =>     \\x64musl: { inputs: [ "libhost.a", app ], output: Shared },
        CpuArchOS.X64v1musl =>   \\x64v1musl: { inputs: [ "libhost.a", app ], output: Shared },
        CpuArchOS.Arm64musl =>   \\arm64musl: { inputs: [ "libhost.a", app ], output: Shared },
        CpuArchOS.Arm64v1musl => \\arm64v1musl: { inputs: [ "libhost.a", app ], output: Shared },
        CpuArchOS.X64mac =>      \\x64mac: { inputs: [ "libhost.a", app ], output: Shared },
        CpuArchOS.Arm64mac =>    \\arm64mac: { inputs: [ "libhost.a", app ], output: Shared },
        CpuArchOS.X64win =>      \\x64win: { inputs: ["host.lib", app], output: Shared },
        CpuArchOS.X64mingw =>    \\x64mingw: { inputs: ["host.lib", app], output: Shared },
        CpuArchOS.Arm64win =>    \\arm64win: { inputs: ["host.lib", app], output: Shared },
        CpuArchOS.Arm64mingw =>  \\arm64mingw: { inputs: ["host.lib", app], output: Shared },
    }
}

u64_or_0 : Try(U64, [Missing]) -> U64
u64_or_0 = |h|
    match h {
        Ok(n) => n
        Err(_) => 0
    }
