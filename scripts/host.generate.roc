#!/usr/bin/env roc

## Generate Roc + Zig bindings from Godot's extension_api.json
##
## Usage:
##   roc run scripts/extension_api.generate.roc -- --engine=godot
##   roc run scripts/extension_api.generate.roc -- --engine=godot4.5
##   roc run scripts/extension_api.generate.roc -- --engine=redot26.3
##
## Path slug (dump-out/ / platform-out/ / host/glue-out/):
##   godot4.7 | godot4.5 | redot26.3 | blazium0.6

app [main!] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst"
}

import pf.Path
#import pf.Stdout
#import pf.Utc
import pf.OsStr
#import pf.Cmd

# import effects/PathHelper
#
# import modules/Args
import modules/Engine
# import modules/StringHelper
# import modules/ModMap
# import modules/CpuArchOS
# import modules/ExtensionApiRenderer
import modules/BaselineTemplate
import modules/HostTemplate
# import modules/ExtensionApi exposing [
#     #ExtensionApi,
#     MethodDef,
#     UtilityFunction,
#     Singleton,
#     BuiltinClass,
#     ClassDef,
#     SignalDef,
#     EnumDef,
#     PropertyDef,
# ]

main! : List(OsStr) => Try({}, _)
main! = |_args| {

#     str_args = args.map(|a| a.display())
#
#     engine : Engine
#     engine = Args.parse_engine_flag_or_godot4_3(str_args)
#     Stdout.line!("# Engine: ${Str.inspect(engine)}")?
#
#     selected_targets : List(CpuArchOS)
#     selected_targets = Args.parse_targets_flag_or_auto(str_args)
#
#     Stdout.line!("# Targets: ${Str.join_with(selected_targets.map(CpuArchOS.to_name), ",")}")?
#
#     source : Path
#     source = "dump-out/${engine.to_path_slug()}/extension_api.json"

    baseline_engine : Engine
    baseline_engine = Godot({ major: 4, minor: 3 }) # TODO: parse from args..

    host_out_path : Path
    host_out_path = "host"

    Path.join(host_out_path, "baseline.zig")
        .write_utf8!(BaselineTemplate.render(baseline_engine))?

    Path.join(host_out_path, "host.zig")
        .write_utf8!(HostTemplate.render())?

    #Stdout.line!("# total after parse: ${(Utc.now!() - parse_start).to_str()}ns")?
    Ok({})
}
