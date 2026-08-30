{ lib, ... }:
rec {
  manual =
    {
      pkgs,
      rootDoc,
      pathMap ? { },
    }:
    pkgs.stdenvNoCC.mkDerivation {
      name = "manual-docs";
      phases = [ "installPhase" ];
      installPhase = ''
        runHook preInstall
        mkdir $out
        ln -s ${rootDoc} $out/index.md
        ${lib.join "\n" (lib.mapAttrsToList (name: path: ''ln -s "${path}" $out/${name}.md'') pathMap)}
        runHook postInstall
      '';
    };
  buildCommonMarkOptionsDoc =
    { prefixes, nix, ... }:
    lib.join "\n" (
      map (
        prefix:
        let
          rows = lib.mapAttrsToList (
            name: opt:
            let
              shortName = (lib.removePrefix "." (lib.removePrefix prefix name));
              type = "${opt.type}${if opt.readOnly then " (read-only))" else ""}";
              description = opt.description;
            in
            "| ${shortName} | ${type} | ${description} |"
          ) (lib.filterAttrs (name: opt: lib.hasPrefix prefix name) nix);
        in
        ''
          ## ${prefix}
          | Name | Type | Description |
          |------|------|-------------|
          ${lib.join "\n" rows}
        ''
      ) prefixes
    );
  buildModuleDocsDir =
    {
      stdenvNoCC,
      writeText,
      options-docs ? null,
      lib-docs ? null,
      manual-docs ? null,
      ...
    }:
    let
      splitOptionsFiles = lib.mapAttrs (
        prefixName: splitDocs:
        writeText "${prefixName}.md" ("# ${prefixName}\n" + (buildCommonMarkOptionsDoc splitDocs))
      ) options-docs.prefixGroups;
      splitOptionsCmds = [
        "mkdir options"
      ]
      ++ lib.mapAttrsToList (
        prefixName: file: "ln -s ${file} options/${prefixName}.md"
      ) splitOptionsFiles;
      optionsCmds = [ "ln -s ${options-docs.commonMark} options.md" ];
      libsCmds = [
        ''
          for file in "${lib-docs.commonMark}"/**; do
            ln -s "$file"
          done
        ''
      ];
      manualCmds = [
        ''
          for file in "${manual-docs}"/**; do
            ln -s "$file"
          done
        ''
      ];
      cmds =
        lib.optionals (options-docs != null) (
          if options-docs ? prefixGroups then splitOptionsCmds else optionsCmds
        )
        ++ lib.optionals (lib-docs != null) libsCmds
        ++ lib.optionals (manual-docs != null) manualCmds;
    in
    stdenvNoCC.mkDerivation {
      name = "docs";
      buildInputs = [ ];
      phases = [
        "buildPhase"
        "installPhase"
      ];
      buildPhase = ''
        runHook preBuild
        mkdir docs
        (
          cd docs
          ${lib.join "\n" cmds}
        )
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        cp -r docs "$out"
        runHook postInstall
      '';
    };
}
