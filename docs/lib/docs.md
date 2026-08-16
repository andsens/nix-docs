# docs 


## `lib.docs.updateRepo` 

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
      paths."docs/options.md" = options-docs.optionsCommonMark;
    };
  };
```

Run with `nix run '.#update-docs'`

## `lib.docs.lib` 

Using `nixdoc` generate documentation for all annotated functions in the
files referenced through `paths`.

### Arguments

`pkgs`: nixpkgs

`paths` (`{ [String] :: Path }`): An attrset of `{ [RelPath] :: RepoPath}`

### Output

A derivation containing markdown docs structurally mirroring `RepoPath`
with `RelPath` as the root directory.

### Example

```nix
inputs.nix-docs.lib.docs.lib {
  inherit pkgs;
  paths.lib = ./nix/lib;
}
```

## `lib.docs.options` 

Generate options documentation for the NixOS modules in `modules`.
Filters out any option not declared under `repoPath`.

### Arguments

`pkgs`: nixpkgs

`repoPath`: Path to the root of the repository.

`modules`: List of NixOS modules to evaluate and generate documentation for

`repoLinkPrefix`: URL prefix for creating source file links (*optional*)

### Output

The same as [`pkgs.nixosOptionsDoc`](https://github.com/NixOS/nixpkgs/blob/8c50a710ddca43d7a530fb805ad55bde8d0141c5/nixos/lib/make-options-doc/default.nix#L179-L247).
An attrSet of `optionsAsciiDoc`, `optionsCommonMark`, and `optionsJSON`.
All values being derivation files containing the documentation in the corresponding format.

### Example

(in `flake.nix`)
```nix
inputs.docs.lib.docs.options {
  inherit pkgs;
  modules = lib.attrValues self.nixosModules;
  repoPath = toString self;
  repoLinkPrefix = "https://github.com/andsens/nix-kubetree/blob/main";
}
```


