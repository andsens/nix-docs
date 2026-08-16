{ lib, ... }:
{
  /**
    Copy a set of derivations to relative paths in the current working directory.
    Removes any existing destination paths.

    # Arguments

    `pkgs`: nixpkgs

    `paths` (`{ [String] :: Derivation }`): An attrset of `{ [RelPath] :: Derivation}`

    # Example

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
  */
  updateRepo =
    {
      pkgs,
      paths,
    }:
    pkgs.writeShellScriptBin "build-docs" ''
      set -eo pipefail
      copy_dir() {
        local root=$1 dest=$2
        rm -rf "$dest"
        while read -r -d $'\0' file; do
          outpath=$dest/''${file#"$root/"}
          mkdir -p "$(dirname "$outpath")"
          cp --no-preserve=all -L "$file" "$outpath"
        done
      }
      copy_file() {
        local deriv=$1 outpath=$2
        rm -f "$outpath"
        mkdir -p "$(dirname "$outpath")"
        cp --no-preserve=all -L "$deriv" "$outpath"
      }
      ${lib.join "\n" (
        lib.mapAttrsToList (path: deriv: ''
          if [[ -d ${deriv} ]]; then
            find ${deriv} -type f -print0 | copy_dir ${deriv} ${lib.escapeShellArg path}
          else
            copy_file ${deriv} ${lib.escapeShellArg path}
          fi
        '') paths
      )}
    '';
  /**
    Using `nixdoc` generate documentation for all annotated functions in the
    files referenced through `paths`.

    # Arguments

    `pkgs`: nixpkgs

    `paths` (`{ [String] :: Path }`): An attrset of `{ [RelPath] :: RepoPath}`

    # Output

    A derivation containing markdown docs structurally mirroring `RepoPath`
    with `RelPath` as the root directory.

    # Example

    ```nix
    inputs.nix-docs.lib.docs.lib {
      inherit pkgs;
      paths.lib = ./nix/lib;
    }
    ```
  */
  lib =
    {
      pkgs,
      paths,
    }:
    pkgs.callPackage (
      {
        runCommand,
        nixdoc,
        ...
      }:
      runCommand "lib-docs" { } ''
        set -eo pipefail
        mkdir $out
        compile() {
          local root=$1 dest=$2
          while read -r -d $'\0' file; do
            name=''${file#"$root/"}
            name=''${name%'.nix'}
            outpath=$out/$dest/$name.md
            mkdir -p "$(dirname "$outpath")"
            ${lib.getExe nixdoc} --file "$file" \
              --prefix "$dest" --category "$name" --description "$name" | \
              ${lib.getExe pkgs.gnused} 's/{#[^#]\+}//g' >"$outpath"
          done
        }
        ${lib.join "\n" (
          lib.mapAttrsToList (dest: path: ''
            find ${path} -type f -name '*.nix' -print0 | compile ${path} ${lib.escapeShellArg dest}
          '') paths
        )}
      ''
    ) { };
  /**
    Generate options documentation for the NixOS modules in `modules`.
    Filters out any option not declared under `repoPath`.

    # Arguments

    `pkgs`: nixpkgs

    `repoPath`: Path to the root of the repository.

    `modules`: List of NixOS modules to evaluate and generate documentation for

    `repoLinkPrefix`: URL prefix for creating source file links (*optional*)

    # Output

    The same as [`pkgs.nixosOptionsDoc`](https://github.com/NixOS/nixpkgs/blob/8c50a710ddca43d7a530fb805ad55bde8d0141c5/nixos/lib/make-options-doc/default.nix#L179-L247).
    An attrSet of `optionsAsciiDoc`, `optionsCommonMark`, and `optionsJSON`.
    All values being derivation files containing the documentation in the corresponding format.

    # Example

    (in `flake.nix`)
    ```nix
    inputs.docs.lib.docs.options {
      inherit pkgs;
      modules = lib.attrValues self.nixosModules;
      repoPath = toString self;
      repoLinkPrefix = "https://github.com/andsens/nix-kubetree/blob/main";
    }
    ```
  */
  options =
    {
      pkgs,
      repoPath,
      modules,
      repoLinkPrefix ? null,
    }:
    pkgs.callPackage (
      {
        runCommand,
        nixosOptionsDoc,
        stdenv,
        nixos-render-docs,
        ...
      }:
      nixosOptionsDoc {
        options =
          (lib.evalModules {
            modules = modules ++ [ { _module.check = false; } ];
            specialArgs = { inherit pkgs; };
          }).options;
        transformOptions =
          opt:
          opt
          // {
            visible = lib.any (decl: lib.hasPrefix repoPath decl) opt.declarations;
            declarations = map (
              decl:
              let
                subpath = lib.removePrefix "${repoPath}/" (
                  if lib.strings.hasSuffix ".nix" decl then decl else "${decl}/default.nix"
                );
              in
              {
                name = subpath;
              }
              // lib.optionalAttrs (repoLinkPrefix != null) { url = "${repoLinkPrefix}/${subpath}"; }
            ) opt.declarations;
          };

      }
    ) { };
}
