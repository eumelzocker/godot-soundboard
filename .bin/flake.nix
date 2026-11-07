{
  description = "Godot exported game runtime on NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      runtimeLibs = with pkgs; [
        fontconfig
        libX11
        libxext
        wayland
        libdecor
        libxkbcommon
        libGL
        libxcursor
        libxrandr
        libxinerama
        libxi
        alsa-lib
        libpulseaudio
      ];
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = runtimeLibs;

        shellHook = ''
          export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath runtimeLibs}:''${LD_LIBRARY_PATH:-}"
        '';
      };
    };
}
