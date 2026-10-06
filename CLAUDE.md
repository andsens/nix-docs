# nix-docs

`options` in `nix/lib/generate.nix` does the `evalModules` plumbing; copy the
call shape from `k8sss/flake.nix` to onboard a repo.

## Gotchas

1. Testing a fix: `builtins.attrNames options` is too shallow. Force what
   `nixosOptionsDoc` forces: `lib.deepSeq (lib.optionAttrSetToDocList options)
   "ok"`.
2. An option without `defaultText` gets its real default forced; when that
   touches `pkgs`, `self` or derivations, add `defaultText` (a string is enough).
3. flake-parts modules reached through several import chains need a stable
   `key = "${toString __curPos.file}#modules.nixos.<name>";`
   (hercules-ci/flake-parts#251) or they're evaluated once per chain.
4. A module that imports nixpkgs' `qemu-vm.nix` (sbfde's `vm`) reads
   `options.fileSystems`, which only exists in a real `nixosSystem`, so it
   can't be documented.
