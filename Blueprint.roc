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
          		"godot",
                "godotPackages_4_3.godot", # TODO: gd 4.0?
          		"godotPackages_4_5.godot",
          		"redot",
          		"rex",
			]),
		]
	),
	Environment(
		"ci",
		[
			Overlays(["roc"]),
			Command("roc", "rocpkgs.nightly-2026-09-27-a3ce7f1"),
			Tools([
				# compilers
				# roc, via overlay...
				"zig",
				"godot",
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
	Task("ci", [Use("ci"), Run(["scripts/ci.roc", "--", "--baseline=godot", "--engines=none", "--targets=muslx64", "--tests=all", "-Doptimize=Debug"])]),

	#Task("check", [Use("dev"), Run(["scripts/check_all.roc"])]),
	#Task("bundle", [Use("dev"), Run(["scripts/build_bundle.roc"])]),
	#Task("test-bundle", [Use("dev"), Run(["scripts/test_bundle.roc"])]),
	#Task("package-examples", [Use("dev"), Run(["scripts/package_examples.roc"])]),
	#Task("package-docs", [Use("dev"), Run(["scripts/package_docs.roc"])]),
	#Task("test-published", [Use("dev"), Run(["scripts/test_published.roc"])]),
]
