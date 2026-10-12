app [config] { pf: platform "https://github.com/lukewilliamboswell/roc-blueprint/releases/download/0.5.0/CupqPH9snWf11g7tWgcJf4Yg5cJ3K9fhL7fSgqDcqJQH.tar.zst" }

config = [
	Name("gdextension-roc-platform-generator"),
	Overlay("roc", "github:roc-lang/roc-overlay"),
	Overlay("redot", "path:./flakes/redot-nix"),
	Overlay("rex", "path:./flakes/rex-nix"),
	Environment("dev", []), # ... todo
	Environment(
	    "dump-bindings",
		[
		    Overlays(["redot", "rex"]),
		    Tools([
          		# engines
          		"godotPackages_4_5.godot", # sane baseline
                "godot", # latest godot
          		"redot", # latest redot
                "godotPackages_4_3.godot", # oldest godot for max compatibility...
          		"rex", # When api dumps are working...
			]),
		]
	),
	Environment(
		"ci-env",
		[
			Overlays(["roc", "redot"]),
			Command("roc", "rocpkgs.nightly-2026-09-27-a3ce7f1"),
			Tools([
				# compilers
				# roc, via overlay...
				"zig",
				# engines
          		"godotPackages_4_5.godot", # sane baseline
                #"godot", # latest godot
          		#"redot", # latest redot
                #"godotPackages_4_3.godot", # oldest godot for max compatibility...
          		#"rex", # When api dumps are working...
			]),
		],
	),
	Environment(
		"gh-publish-env",
		[
			Overlays(["roc", "redot"]),
			Command("roc", "rocpkgs.nightly-2026-09-27-a3ce7f1"),
			Tools([
			    "gh",
    			# compilers
    			# roc, via overlay...
    			"zig",
    			# engines
          		"godotPackages_4_5.godot", # sane baseline
                "godot", # latest godot
          		"redot", # latest redot
                #"godotPackages_4_3.godot", # oldest godot for max compatibility...
          		#"rex", # When api dumps are working...
			]),
		],
	),
	Environment("nightly-release", []),
	Environment("stable-release", []),
	Environment(
		"web-export",
		[
			Overlays(["roc"]),
			Command("roc", "rocpkgs.nightly-2026-09-27-a3ce7f1"),
			Command("roc-stable", "rocpkgs.nightly-2026-09-27-a3ce7f1"),
			Tools([
			    "godot",
				"godot-export-templates-bin",
				"emscripten",
                #"zig", # [Optional] we use zig's "zig wasm-ld" for testing if objects are linkable.
				#"wabt", # [Optional] we use wasm-objdump to inspect.
			]),
		],
	),
	Shell("default", [Use("dev")]),
	# depends on dump bindings, dev & web export...
	Task("ci", [
	    Use("ci-env"),
		Run([
		    "scripts/ci.roc", "--",
			"--baseline=godot4.5",
			"--engines=none",
			"--targets=x64musl",
			"--tests=all",
			"-Doptimize=Debug"
		])
	]),
	Task("ensure-godot", [
	    Use("ci-env"),
		Run([
		    "godot4.5", "--version"
		])
	]),
	#Task("check", [Use("dev"), Run(["scripts/check_all.roc"])]),
	#Task("bundle", [Use("ci"), Run(["scripts/ci.roc", "--", "--bundle"])]),
	Task("publish", [
	    Use("gh-publish-env"),
		Run([
		    "scripts/publish.roc", "--",
			"--publish",
			"--baseline=godot4.5",
			"--engines=godot-latest,redot-latest",
			"--targets=x64musl,wasm32",
			"-Doptimize=ReleaseFast"
		])
	]),
	#Task("test-bundle", [Use("ci"), Run(["scripts/ci.roc", "--", "--test=all"])]),
	#Task("package-examples", [Use("dev"), Run(["scripts/package_examples.roc"])]),
	#Task("package-docs", [Use("dev"), Run(["scripts/package_docs.roc"])]),
	#Task("test-published", [Use("dev"), Run(["scripts/test_published.roc"])]),
]
