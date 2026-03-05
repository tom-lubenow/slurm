# Non-flake build for Slurm using nixnative
# Usage: nix-build -A sinfo
let
  nixpkgs = import <nixpkgs> {};
  pkgs = nixpkgs;

  # Import nixnative from local path
  nixnativeFlake = builtins.getFlake "path:/home/tom/git/nixnative";
  nixPackage = nixnativeFlake.inputs.nix.packages.x86_64-linux.default;
  ninjaPackages = nixnativeFlake.inputs.nix-ninja.packages.x86_64-linux;

  native = nixnativeFlake.lib.native {
    inherit pkgs nixPackage;
    inherit (ninjaPackages) nix-ninja nix-ninja-task;
  };

  project = import ./nix/project.nix { inherit pkgs native; lib = pkgs.lib; };
in
project.packages
