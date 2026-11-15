# nix-docs

A helper library for generating NixOS module and library documentation.

See [docs/lib](docs/lib) for the functions.

## Option pages

`lib.mkdocs.buildModuleDocsDir` renders the options as tables, a section per prefix. Each option is a row with
its name, type, default and the first paragraph of its description, anchored at the full option name
(`#services.foo.enable`). A click on the row, or Enter on it, opens a second row below it with the full description,
default, example and where the option is declared; an option anchor in the URL opens its row on load.

Pass `values` (`{ "<option name>" = { value = ...; changed = true; }; }`) to add a Value column with the current
values, `changed` ones highlighted, and an enabled or disabled badge on each section whose `<prefix>.enable` has a
value.

The site needs the extensions and assets in `lib.mkdocs.settings`, with `lib.mkdocs.assets` linked into its
`docs_dir` as `nix-docs`:

```nix
pkgs.writeText "mkdocs.yml" (builtins.toJSON (lib.recursiveUpdate {
  site_name = "Docs";
  docs_dir = docsDir; # with `ln -s ${nix-docs.lib.mkdocs.assets} nix-docs` in it
  theme.name = "material";
} nix-docs.lib.mkdocs.settings))
```

The tables are styled for Material for MkDocs, with fallbacks for other themes. `nix flake check` builds a fixture
site with and without values (strict) and runs the tables in headless Chromium (`nix/tests`).
