app [config] { pf: platform "https://github.com/lukewilliamboswell/roc-blueprint/releases/download/0.5.0/CupqPH9snWf11g7tWgcJf4Yg5cJ3K9fhL7fSgqDcqJQH.tar.zst" }

import pf.Tool

# Roc versions:
# https://github.com/roc-lang/roc-overlay/blob/master/sources.json

# roc_version = "nightly-2026-10-01-a932c65"
# roc_pkg : Tool
# roc_pkg = "rocpkgs.${roc_version}"

config = [
	Name("gdextension-roc-platform-generator"),
	Overlay("roc", "github:roc-lang/roc-overlay"),
	Overlay("redot", "path:./flakes/redot-nix"),
	Overlay("rex", "path:./flakes/rex-nix"),
	Overlay("blazium", "path:./flakes/blazium-nix"),
	Shell("default", [Use("dev-env")]),
	Environment("dev-env", [
    	Overlays(["roc"]),
    	Command("roc", "rocpkgs.nightly-2026-10-01-a932c65"),
  			Tools([
				"zig",
                "godotPackages_4_5.godot",
			]),
	]),
	Environment(
		"ci-env",
		[
			Overlays(["roc"]),
			Command("roc", "rocpkgs.nightly-2026-10-01-a932c65"),
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
			Overlays(["roc", "redot", "blazium"]),
			Command("roc", "rocpkgs.nightly-2026-10-01-a932c65"),
			Tools([
			    "gh",
    			"zig",
          		"godotPackages_4_5.godot", # sane baseline
                "godot", # latest godot
                "redot", # latest redot
          		"blazium", # latest blazium
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
			#specified by GHA runner...
			#nix run github:lukewilliamboswell/roc-blueprint/0.5.0 -- run publish -- \
            #--baseline="${BASELINE}" \
            #--engines="${ENGINES}" \
            #--targets="${TARGETS}" \
            #-Doptimize="${OPT}" \
            #${TAG_ARG}
		]),
	]),
]
