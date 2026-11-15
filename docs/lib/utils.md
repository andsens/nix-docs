# utils 


## `lib.utils.updateRepo` 

Copy a set of derivations to relative paths in the current working directory.
Removes any existing destination paths.

### Arguments

`pkgs`: nixpkgs

`paths` (`{ [String] :: Derivation }`): An attrset of `{ [RelPath] :: Derivation}`

### Example

(in `flake.nix`)
```nix
perSystem =
  { pkgs, system, ... }:
  let
    lib-docs = inputs.nix-docs.lib.docs.lib {
      inherit pkgs;
      paths.lib = ./nix/lib;
    };
    options-docs = inputs.docs.lib.docs.options {
      inherit pkgs;
      modules = lib.attrValues self.nixosModules;
      repoPath = toString self;
      repoLinkPrefix = "https://github.com/andsens/nix-kubetree/blob/main";
    };
  in
  {
    apps.update-docs.program = inputs.nix-docs.lib.docs.updateRepo {
      inherit pkgs;
      paths."docs/lib" = "${lib-docs}/lib";
      paths."docs/options.md" = options-docs;
    };
  };
```

Run with `nix run '.#update-docs'`


