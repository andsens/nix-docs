{ lib, ... }:
{
  mkDocs =
    {
      name,
      repoPath,
      repoLinkPrefix,
      options,
      includeOptions ? opt: true,
    }:
    {
      runCommand,
      nixosOptionsDoc,
      stdenv,
      nixos-render-docs,
      ...
    }:

    let
      optionsDoc = nixosOptionsDoc {
        inherit options;
        transformOptions =
          opt:
          opt
          // {
            visible = includeOptions opt;
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
      };
    in
    stdenv.mkDerivation {
      inherit name;
      nativeBuildInputs = [ nixos-render-docs ];
      dontUnpack = true;
      buildPhase = ''
        mkdir out
        ln -s ${optionsDoc.optionsJSON}/share/doc/nixos/options.json out/options.json
        ln -s ${optionsDoc.optionsCommonMark} out/options.md
        ln -s ${optionsDoc.optionsAsciiDoc} out/options.adoc
      '';
      installPhase = ''
        mv out "$out"
      '';
    };
}
