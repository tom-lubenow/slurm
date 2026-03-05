{
  description = "Slurm Workload Manager - nixnative build";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixnative.url = "github:tom-lubenow/nixnative";
  };

  outputs = { self, nixpkgs, nixnative }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      nixPackage = nixnative.inputs.nix.packages.${system}.default;
      ninjaPackages = nixnative.inputs.nix-ninja.packages.${system};
      native = nixnative.lib.native {
        inherit pkgs nixPackage;
        inherit (ninjaPackages) nix-ninja nix-ninja-task;
      };
      project = import ./nix/project.nix { inherit pkgs native; lib = pkgs.lib; };
    in {
      # packages.default builds all components (creates result symlink)
      # Individual targets are in legacyPackages (required for dynamic derivations)
      packages.${system}.default = native.mkBuildAllCheck pkgs "slurm" [
        project.packages.sinfo
        project.packages.squeue
        project.packages.scancel
        project.packages.sbatch
        project.packages.scontrol
        project.packages.slurmd
        project.packages.slurmstepd
        project.packages.slurmctld
      ];

      # legacyPackages exposes build outputs for individual targets:
      #   nix build .#sinfo --print-out-paths
      legacyPackages.${system} = native.mkLegacyPackages project.packages;

      devShells.${system}.default = project.devShells.default;
    };
}
