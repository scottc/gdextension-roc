app [config] { pf: platform "https://github.com/lukewilliamboswell/roc-blueprint/releases/download/0.5.0/CupqPH9snWf11g7tWgcJf4Yg5cJ3K9fhL7fSgqDcqJQH.tar.zst" }

config = [
	Name("gdextension-roc-platform-generator"),
	Overlay("roc", "github:roc-lang/roc-overlay"),
	Overlay("redot", "path:./flakes/redot-nix"),
	Overlay("rex", "path:./flakes/rex-nix"),
	Shell("default", [Use("dev-env")]),
	Environment("dev-env", [
    	Overlays(["roc"]),
    	Command("roc", "rocpkgs.nightly-2026-09-27-a3ce7f1"),
  			Tools([
				"zig",
                "godotPackages_4_5.godot",
			]),
	]),
	Environment(
		"ci-env",
		[
			Overlays(["roc", "redot"]),
			Command("roc", "rocpkgs.nightly-2026-09-27-a3ce7f1"),
			Tools([
				"zig",
          		"godotPackages_4_5.godot",
			]),
		],
	),
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
	Environment(
		"gh-publish-env",
		[
			Overlays(["roc", "redot"]),
			Command("roc", "rocpkgs.nightly-2026-09-27-a3ce7f1"),
			Tools([
			    "gh",
    			"zig",
          		"godotPackages_4_5.godot", # sane baseline
                "godot", # latest godot
          		"redot", # latest redot
                #"godotPackages_4_3.godot", # oldest godot for max compatibility...
          		#"rex", # When api dumps are working...
			]),
		],
	),
	Task("publish", [
	    Use("gh-publish-env"),
		Run([
		    "scripts/publish.roc", "--",
			"--publish",
			"--baseline=godot4.5",
			"--engines=godot-stable,redot-stable",
			"--targets=x64musl,wasm32",
			"-Doptimize=ReleaseFast"
		])
	]),
]
