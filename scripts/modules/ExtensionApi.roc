
ExtensionApi := {
    # header : Header,
    # builtin_class_sizes : List(BuiltinClassSizes),
    # builtin_class_member_offsets : List(BuiltinClassMemberOffsets),
    # global_constants : List(GlobalConstant),
    # global_enums : List(EnumDef),
    # utility_functions : List(UtilityFunction),
    # builtin_classes : List(BuiltinClass),
    # classes : List(ClassDef),
    # singletons : List(Singleton),
    # native_structures : List(NativeStructure),
}.{
    # parser_for : JsonEncoding -> (JsonState -> Try({ rest: JsonState, value: ExtensionApi },
    #     [InvalidJson(Str)]))
    # parser_for = |_je| {
    #     crash "NOT IMPLEMETNED?!@!@!!!!!"
    # }
    ExtensionApi : {
        header : Header,
        builtin_class_sizes : List(BuiltinClassSizes),
        builtin_class_member_offsets : List(BuiltinClassMemberOffsets),
        global_constants : List(GlobalConstant),
        global_enums : List(EnumDef),
        utility_functions : List(UtilityFunction),
        builtin_classes : List(BuiltinClass),
        classes : List(ClassDef),
        singletons : List(Singleton),
        native_structures : List(NativeStructure),
    }

    Header : {
        version_major : U64,
        version_minor : U64,
        version_patch : U64,
        version_status : Str,
        version_build : Str,
        version_full_name : Str,
        precision : Str,
    }

    BuiltinClassSizes : {
        build_configuration : Str,
        sizes : List(NamedSize),
    }

    NamedSize : {
        name : Str,
        size : U64,
    }

    BuiltinClassMemberOffsets : {
        build_configuration : Str,
        classes : List(BuiltinMemberClass),
    }

    BuiltinMemberClass : {
        name : Str,
        members : List(MemberOffset),
    }

    MemberOffset : {
        member : Str,
        offset : U64,
        meta : Try(Str, [Missing]),
    }

    GlobalConstant : {
        name : Str,
        value : I64,
        description : Try(Str, [Missing]),
    }

    EnumDef : {
        name : Str,
        is_bitfield : Try(Bool, [Missing]),
        values : List(EnumValue),
        description : Try(Str, [Missing]),
    }

    EnumValue : {
        name : Str,
        value : I64,
        description : Try(Str, [Missing]),
    }

    UtilityFunction : {
        name : Str,
        return_type : Try(Str, [Missing]),
        category : Str,
        is_vararg : Bool,
        hash : U64,
        arguments : Try(List(Argument), [Missing]),
        description : Try(Str, [Missing]),
    }

    Argument : {
        name : Str,
        type : Str,
        meta : Try(Str, [Missing]),
        default_value : Try(Str, [Missing]),
    }

    MethodDef : {
        name : Str,
        is_const : Bool,
        is_static : Bool,
        is_vararg : Bool,
        is_virtual : Try(Bool, [Missing]),
        hash : U64,
        hash_compatibility : Try(List(U64), [Missing]),
        return_type : Try(Str, [Missing]),
        return_value : Try(ReturnValue, [Missing]),
        arguments : Try(List(Argument), [Missing]),
        description : Try(Str, [Missing]),
    }

    ReturnValue : {
        type : Str,
        meta : Try(Str, [Missing]),
    }

    PropertyDef : {
        type : Str,
        name : Str,
        meta : Try(Str, [Missing]),
        getter : Try(Str, [Missing]),
        setter : Try(Str, [Missing]),
        description : Try(Str, [Missing]),
    }

    SignalDef : {
        name : Str,
        arguments : Try(List(Argument), [Missing]),
        description : Try(Str, [Missing]),
    }

    BuiltinClass : {
        name : Str,
        is_keyed : Bool,
        has_destructor : Bool,
        indexing_return_type : Try(Str, [Missing]),
        brief_description : Try(Str, [Missing]),
        description : Try(Str, [Missing]),
        members : Try(List(PropertyDef), [Missing]),
        constants : Try(List(NamedValue), [Missing]),
        enums : Try(List(EnumDef), [Missing]),
        operators : List(OperatorDef),
        methods : Try(List(MethodDef), [Missing]),
        constructors : List(ConstructorDef),
    }

    NamedValue : {
        name : Str,
        type : Str,
        value : Str,
        description : Try(Str, [Missing]),
    }

    OperatorDef : {
        name : Str,
        right_type : Try(Str, [Missing]),
        return_type : Try(Str, [Missing]),
        description : Try(Str, [Missing]),
    }

    ConstructorDef : {
        index : U64,
        arguments : Try(List(Argument), [Missing]),
        description : Try(Str, [Missing]),
    }

    ClassDef : {
        name : Str,
        is_refcounted : Bool,
        is_instantiable : Bool,
        inherits : Try(Str, [Missing]),
        api_type : Str,
        brief_description : Try(Str, [Missing]),
        description : Try(Str, [Missing]),
        enums : Try(List(EnumDef), [Missing]),
        methods : Try(List(MethodDef), [Missing]),
        properties : Try(List(PropertyDef), [Missing]),
        signals : Try(List(SignalDef), [Missing]),
    }

    Singleton : {
        name : Str,
        type : Str,
    }

    NativeStructure : {
        name : Str,
        format : Str,
    }

}
