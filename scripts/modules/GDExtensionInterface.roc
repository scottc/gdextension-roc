## General purpose C header `.h` types
GDExtensionInterface := {}.{
    InterfaceFn : {
        api_name : Str,
        typedef_name : Str,
        return_type : Str,
        parameters : List(ParamInfo),
        comment : CommentInfo,
    }

    CommentInfo : {
        description : Str,
        name : Str,
        param_docs : List({ doc : Str, name : Str }),
        return_doc : Str,
        since : Str,
    }

    EnumVariant : { name : Str, value : Str }
    StructField : { name : Str, type_str : Str }
    ParamInfo : { name : Str, type_str : Str }

    TypeDefInfo : [
        Alias({ name : Str, type_str : Str }),
        Enum({ name : Str, variants : List(EnumVariant) }),
        Struct({ name : Str, fields : List(StructField) }),
        FuncPtr({ name : Str, return_type : Str, parameters : List(ParamInfo) }),
    ]

    GDExtensionInterfaceItem : { comment: CommentInfo, typedef: TypeDefInfo }

}
