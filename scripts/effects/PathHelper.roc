import pf.Path
import pf.OsStr
import pf.Cmd

PathHelper := {}.{
    # mkdir -p; args must be List(OsStr) on basic-cli 0.23
    ensure_dir! : Path => Try({}, _)
    ensure_dir! = |dir| {
        flag : OsStr
        flag = "-p"
        # Path → Str → OsStr (display/inspect depending on your Path API)
        dir_arg : OsStr
        dir_arg = dir.to_os_str() # Path stringifies in interpolation; annotate as OsStr
        {} = Cmd.exec!("mkdir", [flag, dir_arg])?
        Ok({})
    }

    ensure_platform_dirs! : Path => Try({}, _)
    ensure_platform_dirs! = |roc_out| {
        ensure_dir!(roc_out)?
        ensure_dir!(Path.join(roc_out, "engine"))?
        ensure_dir!(Path.join(roc_out, "engine/math"))?
        ensure_dir!(Path.join(roc_out, "engine/builtin_classes"))?
        ensure_dir!(Path.join(roc_out, "engine/classes"))?
        ensure_dir!(Path.join(roc_out, "engine/singletons"))?
        Ok({})
    }
}
