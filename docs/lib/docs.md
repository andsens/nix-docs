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
      paths."docs/options.md" = options-docs;
    };
  };
```

Run with `nix run '.#update-docs'`

## `lib.docs.lib` 

Using `nixdoc` generate documentation for all annotated functions in
the files referenced through `paths`.

Each `paths` value can be a directory (scanned recursively for `.nix`
files, each rendered to its own `<RelPath>/<file>.md`) or a single
`.nix` file (rendered to `<RelPath>.md` directly).

### Arguments

`pkgs`: nixpkgs

`paths` (`{ [String] :: Path }`): An attrset of `{ [RelPath] :: RepoPath}`

### Output

A derivation containing markdown docs structurally mirroring `RepoPath`
with `RelPath` as the root directory.
The derivation also has passthru options for the same docs in `json` format,
and `nix` (an attrset of `{ [DotPath] :: JsonString }`, one entry per rendered
file) — `commonMark` is also set.

### Example

```nix
inputs.nix-docs.lib.docs.lib {
  inherit pkgs;
  paths.lib = ./nix/lib;
  paths."modules/workload-macros" = ./nix/modules/workload-macros/lib.nix;
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

`prefixGroups` (`{ [String] :: [String] }`): Attrset of `{ [GroupName] :: [OptionNamePrefix] }`.
Generates one additional filtered docs derivation per group, containing only
options whose name starts with one of the given prefixes (*optional*)

### Output

A derivation with the documentation in markdown format.
The derivation also has passthru options for all other available format, which are "asciiDoc", and "json" ("commonMark" is also set).
When `prefixGroups` is set, `passthru.prefixGroups.<GroupName>` provides the same formats
(plus `prefixes`, the prefixes used to filter that group) for each group.

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


