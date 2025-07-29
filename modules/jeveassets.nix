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

  jeveWrapper = pkgs.writeShellScriptBin "jeveassets" ''
    #!${pkgs.runtimeShell}
    cd ${cfg.package}/share/jeveassets
    export CLASSPATH="jeveassets.jar:jmemory.jar:lib/*"

    if [ "$1" = "--shell" ]; then
      echo "Entering jeveassets debug shell"
      exec ${pkgs.bashInteractive}/bin/bash
    fi

    if [ -z "$JEVE_XMX" ]; then
      echo "Error: JEVE_XMX is not set"
      exit 1
    fi

    exec ${pkgs.jdk}/bin/java -Xmx$JEVE_XMX -cp "$CLASSPATH" net.nikr.eve.jeveasset.Main "$@"
  '';

  desktopEntry = pkgs.makeDesktopItem {
    name = "jeveassets";
    exec = "jeveassets";
    icon = jeveIcon;
    comment = "EVE Online Asset Manager";
    desktopName = "jEveAssets";
    categories = [ "Utility" ];
    terminal = false;
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
      default = "1g";
      example = "4g";
      description = "Set the maximum heap size for jEveAssets (e.g., 4g).";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
      jeveWrapper
      desktopEntry
    ];

    environment.sessionVariables = {
      JEVE_XMX = cfg.xmx;
    };
  };
}
