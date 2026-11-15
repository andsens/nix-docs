# Checks of the option pages: a fixture site built strict with mkdocs-material, without and with values, and a
# headless browser opening and closing the cards
{
  pkgs,
  lib,
  docsLib,
}:
let
  options-docs = docsLib.docs.options {
    inherit pkgs;
    repoPath = toString ./fixture;
    modules = [ ./fixture/module.nix ];
    repoLinkPrefix = "https://example.org/fixture";
    prefixGroups = {
      alpha = [ "fixture.alpha" ];
      beta = [ "fixture.beta" ];
      gamma = [ "fixture.gamma" ];
    };
  };
  docsDir =
    values:
    pkgs.callPackage docsLib.mkdocs.buildModuleDocsDir {
      inherit options-docs values;
    };
  python = pkgs.python3.withPackages (p: [
    p.mkdocs
    p.mkdocs-material
  ]);
  site =
    name: values:
    let
      config = pkgs.writeText "mkdocs.yml" (
        builtins.toJSON (
          lib.recursiveUpdate {
            site_name = "fixture";
            docs_dir = "docs";
            theme.name = "material";
            theme.features = [ "navigation.instant" ];
          } docsLib.mkdocs.settings
        )
      );
    in
    pkgs.runCommand "fixture-site-${name}" { nativeBuildInputs = [ python ]; } ''
      mkdir docs
      cp -rL ${docsDir values}/. docs/
      echo "# fixture" > docs/index.md
      cp -r ${docsLib.mkdocs.assets} docs/nix-docs
      cp ${config} mkdocs.yml
      mkdocs build --strict --site-dir "$out"
    '';
  plain = site "plain" null;
  withValues = site "values" (import ./fixture/values.nix);
in
{
  docs-site = plain;
  docs-site-values = withValues;
  docs-browser =
    pkgs.runCommand "docs-browser"
      {
        nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.playwright ])) ];
        PLAYWRIGHT_BROWSERS_PATH = pkgs.playwright-driver.browsers;
        PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
      }
      ''
        export HOME=$TMPDIR
        python3 ${./browser.py} ${plain} ${withValues}
        touch $out
      '';
}
