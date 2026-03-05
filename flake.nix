{
  description = "Slurm Workload Manager - nixnative build";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixnative.url = "github:tom-lubenow/nixnative";
  };

  outputs = { self, nixpkgs, nixnative }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          nixPackage = nixnative.inputs.nix.packages.${system}.default;
          ninjaPackages = nixnative.inputs.nix-ninja.packages.${system};
          native = nixnative.lib.native {
            inherit pkgs nixPackage;
            inherit (ninjaPackages) nix-ninja nix-ninja-task;
          };
          project = import ./nix/project.nix { inherit pkgs native; lib = pkgs.lib; };
        in
        f { inherit pkgs native project; }
      );
    in {
      packages = forAllSystems ({ pkgs, native, project, ... }: {
        default = project.packages.all;
      });

      legacyPackages = forAllSystems ({ native, project, ... }:
        native.mkLegacyPackages project.packages
      );

      devShells = forAllSystems ({ project, ... }: {
        default = project.devShells.default;
      });
    };
}
