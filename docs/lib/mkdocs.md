# mkdocs 


## `lib.mkdocs.assets` 

The CSS and JavaScript of the option tables, as a directory to link into the `docs_dir` of a site
(`nix-docs/options.css`, `nix-docs/options.js`).

## `lib.mkdocs.settings` 

mkdocs settings the option pages need: the markdown extensions and the assets, which are expected at `nix-docs/`
in the `docs_dir` (see `assets`). Merge them into the site's `mkdocs.yml`.

## `lib.mkdocs.buildOptionsMarkdown` 

Markdown for the options under `prefixes`, a section per prefix with a table of its options. Each option is a
row with an anchor named after the option, and a second row below it, hidden until the first is clicked, holding
the full description, default, example and where it is declared.

### Arguments

`prefixes` (`[String]`): option name prefixes, one section each; `""` is one section of all options, without a
heading.

`nix`: the options, as `optionsNix` of `nixosOptionsDoc`.

`values` (`{ [OptionName] :: { value; changed ? Bool } }`, *optional*): the current value of each option, shown in
a Value column; `changed` marks values that differ from the default. A section whose `<prefix>.enable` has a value
says whether it is enabled. Values are rendered with `lib.generators.toPretty`.


