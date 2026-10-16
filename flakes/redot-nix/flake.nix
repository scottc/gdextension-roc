{
  description = "Redot Engine prebuilt binaries (Nix)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, flake-utils }:
    let
      # Option B: overlay for roc-blueprint Overlay("redot", …)
      overlay = final: prev: {
        redot =
          self.packages.${final.stdenv.hostPlatform.system}.redot
            or (throw "redot-nix: no package for ${final.stdenv.hostPlatform.system}");
      };
    in
    (flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        version = "26.3-stable";

        # platform → release asset
        assets = {
          "x86_64-linux" = {
            url = "https://github.com/Redot-Engine/redot-engine/releases/download/redot-${version}/Redot_v${version}_linux_x64.zip";
            hash = "sha256-9HTYkIBsQa8VUTz1qGACQ+JBiC4Rto27lWYONGW1seQ=";
          };

          # nix-prefetch-url --type sha256 'https://github.com/…/Redot_v26.2-stable_linux_arm64.zip'
          "aarch64-linux" = {
            url = "https://github.com/Redot-Engine/redot-engine/releases/download/redot-${version}/Redot_v${version}_linux_arm64.zip";
            hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # prefetch
          };
          # "x86_64-darwin" / "aarch64-darwin" → macos_universal.zip when you pin hashes
        };

        asset = assets.${system} or (throw "Redot: no prebuilt binary for ${system}");

        runtimeLibs = with pkgs; [
          libGL
          libx11
          libxcursor
          libxinerama
          libxext
          libxrandr
          libxrender
          libxi
          libxfixes
          libxkbcommon
          wayland
          alsa-lib
          libpulseaudio
          dbus
          fontconfig
          freetype
          vulkan-loader
          udev
          zlib
          stdenv.cc.cc.lib
        ];

        libPath = pkgs.lib.makeLibraryPath runtimeLibs;

        redot = pkgs.stdenv.mkDerivation {
          pname = "redot";
          inherit version;

          src = pkgs.fetchurl {
            inherit (asset) url hash;
          };

          nativeBuildInputs = [
            pkgs.unzip
            pkgs.autoPatchelfHook
            pkgs.makeWrapper
          ];

          buildInputs = runtimeLibs;

          sourceRoot = ".";
          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            bin="$(find . -maxdepth 3 -type f \( -iname 'redot*' -o -iname 'Redot*' \) ! -name '*.so*' | head -n1)"
            if [ -z "$bin" ]; then
              echo "error: Redot binary not found in archive" >&2
              find . -type f | head -40 >&2
              exit 1
            fi
            install -Dm755 "$bin" $out/bin/.redot-wrapped
            makeWrapper $out/bin/.redot-wrapped $out/bin/redot \
              --prefix LD_LIBRARY_PATH : ${libPath}
            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Redot Engine editor (official release binary)";
            homepage = "https://www.redotengine.org/";
            platforms = builtins.attrNames assets;
            mainProgram = "redot";
          };
        };
      in
      {
        packages.default = redot;
        packages.redot = redot;

        apps.default = {
          type = "app";
          program = "${redot}/bin/redot";
        };
      }
    ))
    // {
      overlays.default = overlay;
    };
}
