{
  description = "godot-roc development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # latest git roc version
    # see flake.lock for the final reproduceable pinned version
    # `flake update` to update pinned version, to latest.
    # roc.url = "github:roc-lang/roc?dir=src";

    # specific roc version
    # via specified commit-id hash:
    # this can be useful
    # if you want to explicitly stick to a version.
    # We use the short hash here, to be consistant with other useages.
    # Searchable string: nightly-2026-09-27-a3ce7f1
    # roc.url = "github:roc-lang/roc/a3ce7f1?dir=src";
    # #roc.url = "path:./flakes/roc-nix"; # TODO:
    # roc.inputs.nixpkgs.follows = "nixpkgs";

    # The flake above uses debug flags etc.
    # It's not the same as the offical release binaries.
    # thebrandonlucas/roc-overlay, references the offical released binaries.
    # the differing behaviour can cause panics, makes development more tricky.
    # TODO: vendor the overlay?
    roc-nightly.url = "github:roc-lang/roc-overlay";

    redot.url = "path:./flakes/redot-nix";
    redot.inputs.nixpkgs.follows = "nixpkgs";

    rex.url = "path:./flakes/rex-nix";
    rex.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, roc-nightly, redot, rex, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        # rocPkg = roc.packages.${system}.roc or null;
        rocNightlyPkg = roc-nightly.packages.${system}.nightly-2026-09-27-a3ce7f1;
        redotPkg = redot.packages.${system}.redot;
        rexPkg = rex.packages.${system}.rex;

      in
      {
        # packages.redot = redot;

        devShells.default = pkgs.mkShell {
          packages = [
            # compilers
            pkgs.zig
            # rocPkg
            rocNightlyPkg

            # engines
            pkgs.godot # latest 4.7.1
            pkgs.godotPackages_4_5.godot # 4.5.1, why 4.5.1? most compatable/featureful, version with redot support etc.
            pkgs.godotPackages_4_3.godot # 4.3.x, ... more support is better then less?
            redotPkg
            rexPkg

            # Web wasm32-emscripten, support & tools.
            pkgs.emscripten # godot 4.5 docs expects emscripten 3.1.62+ when building web templates.
            # pkgs.lld # provides wasm-ld, a lower level alternative to emscripten's emcc wasm-ld driver. Use zig wasm-ld, zig comes with it already.
            pkgs.wabt # for wasm-objdump, cli helper utility

            # Package & publish tools
            pkgs.zip # for zipping & publishing *templates* (not for platform releases)

            # TODO: make slim web_dlink_nothreads_*.zip template flake, with just the required web export.
            pkgs.godot-export-templates-bin # ~1.3GB, all platforms
            # Note: templates are needed by CI, to verify web export works.
          ];

          shellHook = ''
            echo "#
# Welcome to the reproduceable development environment.
#
# These are some of tools that are avaliable:
#
# =Compilers=
# roc:          $(roc version)
# zig:          $(zig version)
#
# =Engines=
# godot:        $(godot --version)
# godot4.5:     $(godot4.5 --version)
# godot4.3:     $(godot4.3 --version)
# redot:        $(redot --version)
# rex:          $(rex --version)
#
# =Optional=
# emcc:         $(emcc -v 2>&1 | head -n1)
# wasm-objdump: $(wasm-objdump --version)
# wasm-ld:      $(zig wasm-ld --version)
# zip:          $(zip --version 2>&1 | head -n2 | tail -n1)
#
# Tip - To get started run the following command:
# roc run create-godot-roc-app.roc
# "

# Godot looks under ~/.local/share/godot/export_templates/<version>/
# Symlink the nix store templates so export finds web_dlink_nothreads_*.zip
TEMPLATES_SRC="${pkgs.godot-export-templates-bin}/share/godot/export_templates"
if [ -d "$TEMPLATES_SRC" ]; then
  mkdir -p "$HOME/.local/share/godot/export_templates"
  # link each version dir (e.g. 4.7.2.stable) if missing
  for d in "$TEMPLATES_SRC"/*; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    target="$HOME/.local/share/godot/export_templates/$name"
    if [ ! -e "$target" ]; then
      ln -sfn "$d" "$target"
    fi
  done
  echo "export templates: $TEMPLATES_SRC"
fi
          '';

          # Optional shell hook: godot's export templates.
          # export GODOT_EXPORT_TEMPLATES="${pkgs.godot-export-templates-bin}/share/godot/export_templates"
          # echo "export templates: ${pkgs.godot-export-templates-bin}"

          # Optional shell hook: help tools that look for EMSDK-style layout
          # export EM_CONFIG="${pkgs.emscripten}/share/emscripten/config"
          # Some scripts expect this; nixpkgs layout varies by version:
          # export EMSDK="${pkgs.emscripten}"
        };
      });
}
