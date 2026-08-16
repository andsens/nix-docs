{ lib, ... }:
{
  copyToRepo =
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
  lib =
    {
      repoPath,
      paths,
      pkgs,
      anchorPrefix ? "function-library-",
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
              --prefix "$dest" --category "$name" --description "$name" \
              --anchor-prefix ${lib.escapeShellArg anchorPrefix} | \
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
  options =
    {
      name,
      repoPath,
      repoLinkPrefix,
      modules,
      optionRoot,
      includeOption ? opt: true,
      pkgs,
      anchorPrefix ? "opt-",
    }:
    pkgs.callPackage (
      {
        runCommand,
        nixosOptionsDoc,
        stdenv,
        nixos-render-docs,
        ...
      }:
      let
        options =
          optionRoot
            (lib.evalModules {
              modules = lib.attrValues modules;
            }).options;
      in
      nixosOptionsDoc {
        inherit options;
        optionIdPrefix = anchorPrefix;
        transformOptions =
          opt:
          opt
          // {
            visible = includeOption opt;
            declarations = map (
              decl:
              let
                subpath = lib.removePrefix "/" (lib.removePrefix repoPath (toString decl));
                subpathFile = if lib.strings.hasSuffix ".nix" subpath then subpath else "${subpath}/default.nix";
              in
              if lib.hasPrefix "file://" (toString decl) || lib.hasPrefix "/nix/store" (toString decl) then
                {
                  url = "${repoLinkPrefix}/${subpathFile}";
                  name = "${name}/${subpathFile}";
                }
              else
                decl
            ) opt.declarations;
          };
      }
    ) { };
}
