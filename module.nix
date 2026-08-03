{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.flclashx;
in
{
  options.programs.flclashx = {
    enable = lib.mkEnableOption "FlClashX proxy client";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.flclashx;
      defaultText = lib.literalExpression "pkgs.flclashx";
      description = "The FlClashX package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
