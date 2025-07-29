{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.programs.jeveassets;

  jeveIcon = pkgs.fetchurl {
    url = "https://wiki.jeveassets.org/_media/wiki/logo.png";
    sha256 = "0y3828ssz7v3hw54099wdcfg66cv2jyb67qr1zbf5wxz16b5i264";
  };
in
{
  options.programs.jeveassets = {
    enable = mkEnableOption "jEveAssets - EVE Online Asset Manager";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ../pkgs/jeveassets { };
      defaultText = literalExpression "pkgs.callPackage ../pkgs/jeveassets { }";
      description = "The jEveAssets package to install";
    };

    xmx = mkOption {
      type = types.str;
      default = "";
      example = "4g";
      description = "Set the maximum heap size for jEveAssets (e.g., 4g). If empty, no memory option is passed.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    environment.variables = mkIf (cfg.xmx != "") {
      JEVE_XMX = cfg.xmx;
    };

    environment.etc."skel/.local/share/applications/jeveassets.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=jEveAssets
      Comment=EVE Online Asset Manager
      Exec=jeveassets
      Icon=${jeveIcon}
      Terminal=false
      Categories=Utility;
    '';
  };
}
