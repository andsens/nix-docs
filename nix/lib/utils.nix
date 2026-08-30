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
          paths."docs/options.md" = options-docs;
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
    pkgs.writeShellScriptBin "update-repo" ''
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
}
