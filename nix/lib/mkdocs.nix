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
  # spaces. Past `max` characters (and three more, so a closing bracket isn't cut alone) it is cut, at the last break
  # point (a space, `.`, `/`, `-`, `}` or `,`) in the second half of `max`, otherwise at `max`, and ends in `…`. The
  # card shows the whole value.
  oneLine =
    max: text:
    let
      joined = lib.concatStringsSep " " (
        lib.filter (w: lib.isString w && w != "") (builtins.split "[[:space:]]+" text)
      );
      breakAt = lib.foldl' (
        acc: i:
        if
          builtins.elem (builtins.substring i 1 joined) [
            " "
            "."
            "/"
            "-"
            "}"
            ","
          ]
        then
          i
        else
          acc
      ) (-1) (lib.range (max / 2) (max - 1));
      cut = builtins.substring 0 (if breakAt >= 0 then breakAt + 1 else max) joined;
    in
    if builtins.stringLength joined <= max + 3 then joined else "${lib.removeSuffix " " cut}…";
  # The row's description: the first sentence of the first paragraph, on one line, cut after the last word within
  # `max` characters and ended with `…`. A cut never leaves a `code` span or a [link](...) open: it backs off to the
  # last word before them. The card shows the whole description.
  summary =
    max: description:
    let
      paragraph = builtins.head (lib.splitString "\n\n" (lib.trim description));
      words = lib.filter (w: lib.isString w && w != "") (builtins.split "[[:space:]]+" paragraph);
      n = builtins.length words;
      upTo = k: lib.concatStringsSep " " (lib.take k words);
      # Words up to the first one that ends a sentence
      sentenceEnd = lib.findFirst (i: builtins.match ".*[.!?]" (builtins.elemAt words (i - 1)) != null) n (
        lib.range 1 n
      );
      count = re: text: builtins.length (lib.filter lib.isList (builtins.split re text));
      balanced = text: lib.mod (count "`" text) 2 == 0 && count "\\[" text == count "]\\(" text;
      fits = k: builtins.stringLength (upTo k) <= max;
      cutAt = lib.findFirst (k: fits k && balanced (upTo k)) 0 (lib.reverseList (lib.range 1 sentenceEnd));
    in
    if n == 0 then
      ""
    else if fits sentenceEnd then
      upTo sentenceEnd
    else if cutAt == 0 then
      upTo sentenceEnd
    else
      "${upTo cutAt} …";
  # A block of Nix inside the card. md_in_html needs the fence flush left, and `markdown` on every level from the
  # table down to the cell.
  nixBlock = text: "\n```nix\n${text}\n```\n";
  # A cell value, escaped, with break points after `.`, `/`, `-` and `}`, so a long token wraps at its parts
  breakable = text: lib.replaceStrings [ "." "/" "-" "}" ] [ ".<wbr>" "/<wbr>" "-<wbr>" "}<wbr>" ] (esc text);
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
          cell = text: if text == null then "<td>—</td>" else "<td><code>${breakable (oneLine 24 text)}</code></td>";
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
              ''<td class="nd-value${lib.optionalString (value.changed or false) " nd-changed"}"${lib.optionalString (value.changed or false) " title=\"Set in this system's configuration\""}><code>${breakable (oneLine 24 valueLine)}</code></td>''
          ))
          ''<td markdown="span">${summary 72 description}</td>''
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
      legend = lib.optionalString withValues ''
        <p class="nd-legend">Value: what this system has. <code class="nd-changed-sample">highlighted</code> where its
        configuration sets the option; the others are at their default.</p>

      '';
    in
    legend + lib.concatMapStringsSep "\n" section prefixes;

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
      # The groups' pages, and no index page: the navigation lists them under the section
      splitOptionsCmds = [
        "mkdir options"
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
