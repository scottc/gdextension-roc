#!/usr/bin/env roc

#
# Usage:
# roc run serve.roc [args]
#

## Serves files.
app [Context, program] {
	pf: platform "https://github.com/roc-lang/basic-webserver/releases/download/0.18.0/9VgbC77zLmYYgxLpiNGCq3eySyRCbE2RriAM4sjr2y81.tar.zst",
	http: "https://github.com/roc-lang/http/releases/download/1.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
}

import pf.Path
import pf.Server
import pf.Stdout
import http.Response
import pf.Env

Context : {}

program = { init!, respond!, shutdown! }

init! : () => Try({ config : Server.Config, context : Context }, [Exit(I64), ..other])
init! = || {

    serve_path = Env.var_str!("SERVE_PATH")

    file_root = match serve_path {
        Ok(p) =>
            Server.file_root_with_cache({
          		id: "serve_path",
          		path: Path.utf8(p),
          		cache: Server.public_for(1),
           	}),
        _ => crash "[scripts/serve.roc] Missing env var SERVE_PATH"
    }

	config =
		Server.default_config
			.with_request_metadata_limits({
				max_target_bytes: 1024 * 10,
				max_header_bytes: 4096 * 10,
				max_header_fields: 24,
			})
			.with_file_roots([file_root])
			.with_native_routes({
				files: [
					Server.static_mount({ at: "/", files: file_root }),
				],
				liveness: [],
				readiness: [],
			})

	Ok({
		config,
		context: {},
	})
}

respond! : Server.Request, Context => Try(Server.Outcome, [ServerErr(Str), ..other])
respond! = |request, _context| {
	target = request.target()
	Stdout.line!("Roc handled ${Str.inspect(target)}")
		? |err| ServerErr("Failed to log request: ${Str.inspect(err)}")

	match target {
		_ =>
			Ok(
				Server.respond(
					Response.from_status(404)
						.with_body(Str.to_utf8("Roc fallback")),
				),
			)
		}
}

shutdown! : Server.ShutdownReason, Context => Try({}, [Exit(I64), ..other])
shutdown! = |_reason, _context| Ok({})
