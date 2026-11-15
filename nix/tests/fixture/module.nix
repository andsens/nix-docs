# Options of every shape the renderer handles, for the checks
{ lib, ... }:
{
  options.fixture = {
    alpha = {
      enable = lib.mkEnableOption "alpha";
      name = lib.mkOption {
        description = ''
          Name of the alpha instance. A pipe | must not break the table.

          A second paragraph, only in the card:

          - a list item
          - `code` in a list
        '';
        type = lib.types.str;
        default = "alpha";
        example = "beta";
      };
      settings = lib.mkOption {
        description = "Settings with a long default spanning lines.";
        type = lib.types.attrsOf lib.types.int;
        default = {
          first = 1;
          second = 2;
          third = 3;
        };
      };
      path = lib.mkOption {
        description = "A long value without whitespace.";
        type = lib.types.str;
        default = "/var/lib/a-rather-long-directory-name/without-any-whitespace/in-it";
      };
      computed = lib.mkOption {
        description = "A read-only option with a literal default.";
        type = lib.types.str;
        readOnly = true;
        default = "x";
        defaultText = lib.literalExpression "config.fixture.alpha.name + \"-computed\"";
      };
    };
    # An option named like its section
    gamma = lib.mkOption {
      description = "An option whose name is the prefix of its group.";
      type = lib.types.attrsOf lib.types.str;
      default = { };
    };
    beta = {
      enable = lib.mkEnableOption "beta";
      peers = lib.mkOption {
        description = "Peers, by name.";
        default = { };
        type = lib.types.attrsOf (
          lib.types.submodule {
            options.address = lib.mkOption {
              description = "Address of the <peer>.";
              type = lib.types.str;
            };
          }
        );
      };
    };
  };
}
