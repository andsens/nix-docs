{
  description = "Nix Kubetree";
  inputs = {
    systems.url = "github:nix-systems/default-linux";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };
  outputs =
    {
      systems,
      flake-parts,
      nixpkgs,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (
      {
        flake-parts-lib,
        self,
        lib,
        ...
      }:
      {
        systems = import systems;
        flake = {
          lib.docs = import ./nix/lib/docs.nix { inherit lib; };
        };
        perSystem =
          { pkgs, system, ... }:
          rec {
            apps.docs.program = self.lib.docs.copyToRepo {
              inherit pkgs;
              paths."docs/lib" = "${packages.lib-docs}/lib";
            };
            packages = {
              lib-docs = self.lib.docs.lib {
                inherit pkgs;
                repoPath = toString self;
                paths.lib = ./nix/lib;
              };
            };
          };
      }
    );
}
