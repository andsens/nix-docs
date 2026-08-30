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
          lib.docs = import ./nix/lib/generate.nix { inherit lib; };
          lib.mkdocs = import ./nix/lib/mkdocs.nix { inherit lib; };
          lib.utils = import ./nix/lib/util.nix { inherit lib; };
        };
        perSystem =
          { pkgs, system, ... }:
          let
            lib-docs = self.lib.docs.lib {
              inherit pkgs;
              paths.lib = ./nix/lib;
            };
          in
          {
            apps.update-docs.program = self.lib.docs.updateRepo {
              inherit pkgs;
              paths."docs/lib" = "${lib-docs}/lib";
            };
            packages.lib-docs = lib-docs;
          };
      }
    );
}
