import Engine
import CpuArchOS

Args := {}.{
    ## --baseline=godot4.5
    parse_engine_flag : List(Str) -> Try(Engine, [MissingRequiredBaselineFlag(str)])
    parse_engine_flag = |_args| {
        #crash "parse_engine_flag not implemented."

        # for str in args {
        #     if str.starts_with("--engine=") {
        #         id = str.replace_first("--engine=", "")
        #         Ok(Engine.from_name(id))
        #     }
        # }

        Ok(Godot({ major: 4, minor: 5 }))
        #Err(MissingRequiredBaselineFlag("Missing: --engine="))
    }

    ## --baseline=godot4.5
    parse_baseline_flag : List(Str) -> Try(Engine, [MissingRequiredBaselineFlag(str)])
    parse_baseline_flag = |_args| {
        #crash "parse_baseline_flag not implemented."

#         for str in args {
#             if str.starts_with("--baseline=") {
#                 id = str.replace_first("--baseline=", "")
#                 Engine.from_name(id)
#
#             }
#         }
        Ok(Godot({ major: 4, minor: 5 }))
        #Err(MissingRequiredBaselineFlag("Missing: --baseline="))
    }

    ## --engines=godot4.5,redot26.2,rex0.0
    parse_engines_flag : List(Str) -> Try(List(Engine), _)
    parse_engines_flag = |_args| {
        #crash "parse_engines_flag not implemented."

        # baseline_key = "--engines="
        # for str in args {
        #     if str.starts_with(engine_key) {
        #         id = str.replace_first(engine_key, "")
        #         match Engine.from_name(id) {
        #             Ok(v) => Ok([v])
        #             other => other
        #         }
        #     }
        # }
        Ok([Godot({ major: 4, minor: 5 }), Godot({ major: 4, minor: 7 })])
    }
}
