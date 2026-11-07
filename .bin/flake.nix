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

        # nix-ld starts the export with the loader in NIX_LD. Using this nixpkgs' loader keeps glibc
        # and the dlopen()ed audio and display libraries on the same version; a newer alsa-lib or
        # libpulse under the system glibc fails and leaves Godot on the silent dummy audio driver.
        shellHook = ''
          export NIX_LD="$(cat ${pkgs.stdenv.cc}/nix-support/dynamic-linker)"
          export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath runtimeLibs}:''${LD_LIBRARY_PATH:-}"
        '';
      };
    };
}
