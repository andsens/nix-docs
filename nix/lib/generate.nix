{ lib, ... }:
{
  /**
    Using `nixdoc` generate documentation for all annotated functions in
    the files referenced through `paths`.

    Each `paths` value can be a directory (scanned recursively for `.nix`
    files, each rendered to its own `<RelPath>/<file>.md`) or a single
    `.nix` file (rendered to `<RelPath>.md` directly).

    # Arguments

    `pkgs`: nixpkgs

    `paths` (`{ [String] :: Path }`): An attrset of `{ [RelPath] :: RepoPath}`

    # Output

    A derivation containing markdown docs structurally mirroring `RepoPath`
    with `RelPath` as the root directory.
    The derivation also has passthru options for the same docs in `json` format,
    and `nix` (an attrset of `{ [DotPath] :: JsonString }`, one entry per rendered
    file) — `commonMark` is also set.

    # Example

    ```nix
    inputs.nix-docs.lib.docs.lib {
      inherit pkgs;
      paths.lib = ./nix/lib;
      paths."modules/workload-macros" = ./nix/modules/workload-macros/lib.nix;
    }
    ```
  */
  lib =
    {
      pkgs,
      paths,
    }:
    let
      dotPaths =
        dir:
        lib.concatMapAttrs (
          name: type:
          let
            path = "${dir}/${name}";
            key = lib.removeSuffix ".json" name;
          in
          if type == "directory" then
            lib.mapAttrs' (subKey: value: {
              name = "${key}.${subKey}";
              inherit value;
            }) (dotPaths path)
          else
            { ${key} = builtins.readFile path; }
        ) (builtins.readDir dir);
      docs = lib.mergeAttrsList (
        map
          (
            format:
            let
              ext = if format == "json" then "json" else "md";
              jsonArg = if format == "json" then "--json-output" else "";
            in
            {
              ${format} = pkgs.stdenvNoCC.mkDerivation {
                name = "lib-docs";
                buildInputs = with pkgs; [
                  bash
                  coreutils
                  gnused
                  nixdoc
                ];

                phases = [
                  "buildPhase"
                  "installPhase"
                ];

                buildPhase = ''
                  runHook preBuild
                  set -eo pipefail
                  mkdir lib-docs
                  render() {
                    local file=$1 prefix=$2 category=$3 outpath=$4
                    mkdir -p "$(dirname "$outpath")"
                    nixdoc --file "$file" ${jsonArg} \
                      --prefix "$prefix" --category "$category" --description "$category" | \
                      ${lib.getExe pkgs.gnused} 's/{#[^#]\+}//g' >"$outpath.${ext}"
                  }
                  compile_dir() {
                    local root=$1 dest=$2
                    while read -r -d $'\0' file; do
                      local name=''${file#"$root/"}
                      name=''${name%'.nix'}
                      render "$file" "$dest" "$name" "lib-docs/$dest/$name"
                    done
                  }
                  compile_file() {
                    local file=$1 dest=$2 category
                    category=$(${lib.getExe pkgs.gnused} -E 's/^[0-9a-z]{32}-//' <<<"''${file##*/}")
                    category=''${category%'.nix'}
                    render "$file" "$dest" "$category" "lib-docs/$dest"
                  }
                  ${lib.join "\n" (
                    lib.mapAttrsToList (dest: path: ''
                      if [[ -d ${path} ]]; then
                        find ${path} -type f -name '*.nix' -print0 | compile_dir ${path} ${lib.escapeShellArg dest}
                      else
                        compile_file ${path} ${lib.escapeShellArg dest}
                      fi
                    '') paths
                  )}
                  runHook postBuild
                '';

                installPhase = ''
                  runHook preInstall
                  cp -r lib-docs "$out"
                  runHook postInstall
                '';
              };
            }
          )
          [
            "json"
            "commonMark"
          ]
      );
    in
    pkgs.stdenvNoCC.mkDerivation {
      name = "lib-docs";
      phases = [ "installPhase" ];
      installPhase = ''
        runHook preInstall
        ln -s ${docs.commonMark} "$out"
        runHook postInstall
      '';
      passthru = {
        commonMark = docs.commonMark;
        json = docs.json;
        nix = dotPaths docs.json;
      };
    };
  /**
    Generate options documentation for the NixOS modules in `modules`.
    Filters out any option not declared under `repoPath`.

    # Arguments

    `pkgs`: nixpkgs

    `repoPath`: Path to the root of the repository.

    `modules`: List of NixOS modules to evaluate and generate documentation for

    `repoLinkPrefix`: URL prefix for creating source file links (*optional*)

    `prefixGroups` (`{ [String] :: [String] }`): Attrset of `{ [GroupName] :: [OptionNamePrefix] }`.
    Generates one additional filtered docs derivation per group, containing only
    options whose name starts with one of the given prefixes (*optional*)

    # Output

    A derivation with the documentation in markdown format.
    The derivation also has passthru options for all other available format, which are "asciiDoc", and "json" ("commonMark" is also set).
    When `prefixGroups` is set, `passthru.prefixGroups.<GroupName>` provides the same formats
    (plus `prefixes`, the prefixes used to filter that group) for each group.

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
      prefixGroups ? null,
    }:
    let
      docs =
        {
          filterPrefixes ? null,
        }:
        pkgs.nixosOptionsDoc {
          options =
            (lib.evalModules {
              modules = modules ++ [ { _module.check = false; } ];
              specialArgs = { inherit pkgs; };
            }).options;
          transformOptions =
            opt:
            opt
            // {
              visible =
                (lib.any (decl: lib.hasPrefix repoPath decl) opt.declarations)
                && (filterPrefixes == null || (lib.any (prefix: lib.hasPrefix prefix opt.name) filterPrefixes));
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
        };
      allDocs = docs { };
    in
    pkgs.stdenvNoCC.mkDerivation {
      name = "options-docs";
      phases = [ "installPhase" ];
      installPhase = ''
        runHook preInstall
        ln -s ${allDocs.optionsCommonMark} "$out"
        runHook postInstall
      '';
      passthru = {
        commonMark = allDocs.optionsCommonMark;
        json = "${allDocs.optionsJSON}/share/doc/nixos/options.json";
        asciiDoc = allDocs.optionsAsciiDoc;
        nix = allDocs.optionsNix;
      }
      // lib.optionalAttrs (prefixGroups != null) {
        prefixGroups = lib.mapAttrs (
          name: filterPrefixes:
          let
            splitDocs = docs { inherit filterPrefixes; };
          in
          pkgs.stdenvNoCC.mkDerivation {
            name = "options-docs-${name}";
            phases = [ "installPhase" ];
            installPhase = ''
              runHook preInstall
              ln -s ${splitDocs.optionsCommonMark} "$out"
              runHook postInstall
            '';
            passthru = {
              prefixes = filterPrefixes;
              commonMark = splitDocs.optionsCommonMark;
              json = "${splitDocs.optionsJSON}/share/doc/nixos/options.json";
              asciiDoc = splitDocs.optionsAsciiDoc;
              nix = splitDocs.optionsNix;

            };
          }
        ) prefixGroups;
      };
    };
}
