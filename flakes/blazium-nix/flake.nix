{
  description = "Blazium Engine prebuilt binaries (Nix)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, flake-utils }:
    let
      # Option B: overlay for roc-blueprint Overlay("blazium", …)
      overlay = final: prev: {
        blazium =
          self.packages.${final.stdenv.hostPlatform.system}.blazium
            or (throw "blazium-nix: no package for ${final.stdenv.hostPlatform.system}");
      };
    in
    (flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        version = "0.6.927";

        # platform → release asset (non-mono editor)
        assets = {
          "x86_64-linux" = {
            url = "https://github.com/blazium-games/blazium/releases/download/v${version}/BlaziumEditor_v${version}_linux.x86_64.zip";
            hash = "sha256-iVY0zNQrQOuC8DQ940inVVUbM4K2LkK/n1+6/41jQv4=";
          };

          # Optional: mono Linux x86_64 (uncomment if you need C#)
          # "x86_64-linux-mono" = {
          #   url = "https://github.com/blazium-games/blazium/releases/download/v${version}/BlaziumEditor_v${version}_linux.mono.x86_64.zip";
          #   hash = "sha256-VhGIxCt6nJXZdTTL++5IeSKsrJ12ZiZ5GUCTI5SUcL8=";
          # };

          # nix-prefetch-url --type sha256 '…' when you add more platforms
          # "aarch64-linux" = { … };
          # "x86_64-darwin" / "aarch64-darwin" → macos zip when available
        };

        asset = assets.${system} or (throw "Blazium: no prebuilt binary for ${system}");

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

        blazium = pkgs.stdenv.mkDerivation {
          pname = "blazium";
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
            bin="$(find . -maxdepth 3 -type f \( -iname 'blazium*' -o -iname 'Blazium*' \) ! -name '*.so*' ! -name '*.pck' | head -n1)"
            if [ -z "$bin" ]; then
              echo "error: Blazium binary not found in archive" >&2
              find . -type f | head -40 >&2
              exit 1
            fi
            install -Dm755 "$bin" $out/bin/.blazium-wrapped
            makeWrapper $out/bin/.blazium-wrapped $out/bin/blazium \
              --prefix LD_LIBRARY_PATH : ${libPath}
            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Blazium Engine editor (official release binary)";
            homepage = "https://blazium.app/";
            platforms = builtins.attrNames assets;
            mainProgram = "blazium";
          };
        };
      in
      {
        packages.default = blazium;
        packages.blazium = blazium;

        apps.default = {
          type = "app";
          program = "${blazium}/bin/blazium";
          meta = {
            description = "Blazium Engine editor";
          };
        };
      }
    ))
    // {
      overlays.default = overlay;
    };
}
