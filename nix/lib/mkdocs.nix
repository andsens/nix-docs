{ lib, ... }:
let
  esc = lib.escapeXML;
  # The text of a `literalExpression`, `literalMD` or plain default/example, null when there is none
  literalText =
    v:
    if v == null then
      null
    else if lib.isAttrs v && v ? _type && v ? text then
      v.text
    else
      lib.generators.toPretty { } v;
  # One line for a table cell: the whole text with its whitespace runs (newlines and indentation included) as single
  # spaces, cut after the last word that fits in `max` characters, never inside a word. The first two words stay
  # whatever their length, so a long path or name wraps in the cell rather than leaving `[` alone, and a rest of
  # three characters or fewer stays too.
  oneLine =
    max: text:
    let
      words = lib.filter (w: lib.isString w && w != "") (builtins.split "[[:space:]]+" text);
      n = builtins.length words;
      upTo = k: lib.concatStringsSep " " (lib.take k words);
      # The most words that fit, at least two
      fitting = lib.max (lib.min 2 n) (
        lib.foldl' (k: i: if builtins.stringLength (upTo i) <= max then i else k) 0 (lib.range 1 n)
      );
      # A short rest (a closing bracket) goes in rather than leaving an ellipsis for it
      rest = builtins.stringLength (lib.concatStringsSep " " (lib.drop fitting words));
      k = if rest <= 3 then n else fitting;
    in
    if k == n then upTo n else "${upTo k} …";
  # The first paragraph of a description, on one line
  summary =
    description:
    let
      paragraph = builtins.head (lib.splitString "\n\n" (lib.trim description));
    in
    lib.concatStringsSep " " (map lib.trim (lib.splitString "\n" paragraph));
  # A block of Nix inside the card. md_in_html needs the fence flush left, and `markdown` on every level from the
  # table down to the cell.
  nixBlock = text: "\n```nix\n${text}\n```\n";
  hasPrefixPath = prefix: name: prefix == "" || name == prefix || lib.hasPrefix "${prefix}." name;
in
rec {
  /**
    The CSS and JavaScript of the option tables, as a directory to link into the `docs_dir` of a site
    (`nix-docs/options.css`, `nix-docs/options.js`).
  */
  assets = ./assets;

  /**
    mkdocs settings the option pages need: the markdown extensions and the assets, which are expected at `nix-docs/`
    in the `docs_dir` (see `assets`). Merge them into the site's `mkdocs.yml`.
  */
  settings = {
    markdown_extensions = [
      "md_in_html"
      "attr_list"
      "tables"
      "admonition"
      "pymdownx.superfences"
      "pymdownx.highlight"
    ];
    extra_css = [ "nix-docs/options.css" ];
    extra_javascript = [ "nix-docs/options.js" ];
  };

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

  /**
    Markdown for the options under `prefixes`, a section per prefix with a table of its options. Each option is a
    row with an anchor named after the option, and a second row below it, hidden until the first is clicked, holding
    the full description, default, example and where it is declared.

    # Arguments

    `prefixes` (`[String]`): option name prefixes, one section each; `""` is one section of all options, without a
    heading.

    `nix`: the options, as `optionsNix` of `nixosOptionsDoc`.

    `values` (`{ [OptionName] :: { value; changed ? Bool } }`, *optional*): the current value of each option, shown in
    a Value column; `changed` marks values that differ from the default. A section whose `<prefix>.enable` has a value
    says whether it is enabled. Values are rendered with `lib.generators.toPretty`.
  */
  buildOptionsMarkdown =
    {
      prefixes,
      nix,
      values ? null,
      ...
    }:
    let
      withValues = values != null;
      columns = if withValues then 5 else 4;
      row =
        prefix: name: opt:
        let
          # The option named like its section (`homelab.kubernetes` under `homelab.kubernetes`) keeps its full name
          shortName = if prefix == "" || name == prefix then name else lib.removePrefix "${prefix}." name;
          type = "${opt.type}${lib.optionalString (opt.readOnly or false) " (read-only)"}";
          default = literalText (opt.default or null);
          example = literalText (opt.example or null);
          description = opt.description or "";
          value = if withValues then values.${name} or null else null;
          valueText = if value == null then null else lib.generators.toPretty { } value.value;
          # The cell gets the value on one line; the card keeps it laid out
          valueLine = if value == null then null else lib.generators.toPretty { multiline = false; } value.value;
          declarations = opt.declarations or [ ];
          declLink = d: if d ? url then "[`${d.name}`](${d.url})" else "`${d.name}`";
          cell = text: if text == null then "<td>—</td>" else "<td><code>${esc (oneLine 40 text)}</code></td>";
        in
        lib.concatStrings [
          ''<tr class="nd-option" id="${esc name}" tabindex="0" aria-expanded="false" markdown="1">''
          ''<td><a class="nd-name" href="#${esc name}"><code>${lib.replaceStrings [ "." ] [ ".<wbr>" ] (esc shortName)}</code></a></td>''
          "<td>${esc type}</td>"
          (cell default)
          (lib.optionalString withValues (
            if valueText == null then
              ''<td class="nd-value">—</td>''
            else
              ''<td class="nd-value${lib.optionalString (value.changed or false) " nd-changed"}"><code>${esc (oneLine 40 valueLine)}</code></td>''
          ))
          ''<td markdown="span">${summary description}</td>''
          "</tr>\n"
          ''<tr class="nd-card" hidden markdown="1"><td colspan="${toString columns}" markdown="block">''
          "\n\n"
          "`${name}`\n\n"
          (if description == "" then "*No description.*\n" else "${lib.trim description}\n")
          (lib.optionalString (valueText != null) (
            "\n**Value**${lib.optionalString (value.changed or false) " (changed)"}\n${nixBlock valueText}"
          ))
          (lib.optionalString (default != null) "\n**Default**\n${nixBlock default}")
          (lib.optionalString (example != null) "\n**Example**\n${nixBlock example}")
          (lib.optionalString (declarations != [ ]) (
            "\n**Declared in** ${lib.concatMapStringsSep ", " declLink declarations}\n"
          ))
          "\n</td></tr>\n"
        ];
      section =
        prefix:
        let
          opts = lib.filterAttrs (name: _: hasPrefixPath prefix name) nix;
          enable = if withValues && prefix != "" then values."${prefix}.enable" or null else null;
          badge =
            if enable == null then
              ""
            else if enable.value == true then
              "\n\n<span class=\"nd-badge nd-enabled\">enabled</span>\n"
            else
              "\n\n<span class=\"nd-badge nd-disabled\">disabled</span>\n";
        in
        lib.concatStrings [
          (lib.optionalString (prefix != "") "## ${prefix}${badge}\n\n")
          ''<table class="nd-options${lib.optionalString withValues " nd-with-values"}" markdown="1">''
          "\n<thead><tr><th>Name</th><th>Type</th><th>Default</th>"
          (lib.optionalString withValues "<th>Value</th>")
          "<th>Description</th></tr></thead>\n<tbody markdown=\"1\">\n"
          (lib.concatStrings (lib.mapAttrsToList (row prefix) opts))
          "</tbody>\n</table>\n"
        ];
    in
    lib.concatMapStringsSep "\n" section prefixes;

  buildModuleDocsDir =
    {
      stdenvNoCC,
      writeText,
      options-docs ? null,
      lib-docs ? null,
      manual-docs ? null,
      values ? null,
      ...
    }:
    let
      splitOptionsFiles = lib.mapAttrs (
        prefixName: splitDocs:
        writeText "${prefixName}.md" (
          "# ${prefixName}\n\n"
          + buildOptionsMarkdown {
            inherit (splitDocs) prefixes nix;
            inherit values;
          }
        )
      ) options-docs.prefixGroups;
      # options/ gets a page of its own, linking the groups
      splitOptionsIndex = writeText "index.md" (
        "# Options\n\n"
        + lib.concatMapStrings (prefixName: "- [${prefixName}](${prefixName}.md)\n") (
          lib.attrNames splitOptionsFiles
        )
      );
      splitOptionsCmds = [
        "mkdir options"
        "ln -s ${splitOptionsIndex} options/index.md"
      ]
      ++ lib.mapAttrsToList (
        prefixName: file: "ln -s ${file} options/${prefixName}.md"
      ) splitOptionsFiles;
      optionsFile = writeText "options.md" (
        "# Options\n\n"
        + buildOptionsMarkdown {
          prefixes = [ "" ];
          inherit (options-docs) nix;
          inherit values;
        }
      );
      optionsCmds = [ "ln -s ${optionsFile} options.md" ];
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
