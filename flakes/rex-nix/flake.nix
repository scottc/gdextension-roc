{
  description = "ReX Engine prebuilt binary (Nix)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, flake-utils }:
    let
      # Option B: overlay for roc-blueprint Overlay("rex", …)
      overlay = final: prev: {
        rex =
          self.packages.${final.stdenv.hostPlatform.system}.rex
            or (throw "rex-nix: no package for ${final.stdenv.hostPlatform.system}");
      };
    in
    (flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        version = "0.0.1";

        src = pkgs.fetchurl {
          url = "https://github.com/Redot-Engine/rex-release/releases/download/v${version}/linuxbsd-x86_64-mono.zip";
          hash = "sha256-egOD4zGazAbbifKEPPLD8KNg/ahlIaffyULqA6jtzq8=";
        };

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
          icu
          openssl
          stdenv.cc.cc.lib
        ];

        libPath = pkgs.lib.makeLibraryPath runtimeLibs;
        dotnet = pkgs.dotnet-sdk_8;

        rex = pkgs.stdenv.mkDerivation {
          pname = "rex";
          inherit version src;

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
            mkdir -p $out/bin $out/libexec/rex

            if [ ! -f ./linuxbsd-x86_64-mono/rex.linuxbsd.editor.x86_64 ]; then
              echo "error: expected ./linuxbsd-x86_64-mono/rex.linuxbsd.editor.x86_64" >&2
              find . -type f | head -40 >&2
              exit 1
            fi

            cp -a ./linuxbsd-x86_64-mono/. $out/libexec/rex/
            chmod +x $out/libexec/rex/rex.linuxbsd.editor.x86_64

            makeWrapper $out/libexec/rex/rex.linuxbsd.editor.x86_64 $out/bin/rex \
              --prefix LD_LIBRARY_PATH : ${libPath} \
              --prefix PATH : ${dotnet}/bin \
              --set DOTNET_ROOT ${dotnet} \
              --chdir $out/libexec/rex

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "ReX Engine editor (official Linux x64 mono build)";
            homepage = "https://github.com/Redot-Engine/DraconicEngine";
            platforms = [ "x86_64-linux" ];
            mainProgram = "rex";
          };
        };
      in
      {
        packages.rex = rex;
        packages.default = rex;
      }
    ))
    // {
      overlays.default = overlay;
    };
}
