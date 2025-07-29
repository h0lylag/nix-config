{
  pkgs ? import <nixpkgs> { },
}:

let
  version = "8.0.3";

  # 1) Upstream ZIP
  src = pkgs.fetchzip {
    url = "https://github.com/GoldenGnu/jeveassets/releases/download/jeveassets-${version}/jeveassets-${version}.zip";
    sha256 = "dxVLvDrTLCtBrldJ/gyYTE8rXOOGNO2PGT61aCg9ZyI=";
  };

  # 2) Icon PNG
  icon = pkgs.fetchurl {
    url = "https://wiki.jeveassets.org/_media/wiki/logo.png";
    sha256 = "0y3828ssz7v3hw54099wdcfg66cv2jyb67qr1zbf5wxz16b5i264";
  };

  # 3) Build the script + assets + icon
  scriptDrv = pkgs.stdenv.mkDerivation rec {
    pname = "jeveassets";
    inherit version src icon;

    buildInputs = [ pkgs.jdk ];

    installPhase = ''
            # create output dirs
            mkdir -p $out/bin \
                     $out/share/jeveassets \
                     $out/share/icons/hicolor/64x64/apps

            # copy all unpacked ZIP contents (including dot-files)
            cp -r ${src}/. $out/share/jeveassets

            # install icon with correct perms
            install -Dm644 ${icon} \
              $out/share/icons/hicolor/64x64/apps/jeveassets.png

            # launcher wrapper with build-time $out expansion + exec-print
            cat > $out/bin/jeveassets <<EOF
      #!${pkgs.runtimeShell}
      # jump straight into the real store path
      cd $out/share/jeveassets

      export CLASSPATH="jeveassets.jar:jmemory.jar:lib/*"

      if [ "\$1" = "--shell" ]; then
        echo "Entering jeveassets debug shell"
        exec ${pkgs.runtimeShell}
      fi

      XMS="512m"
      XMX="4g"

      # assemble and print the Java invocation
      CMD="${pkgs.jdk}/bin/java -Xms\$XMS -Xmx\$XMX -cp \"\$CLASSPATH\" net.nikr.eve.jeveasset.Main \$@"
      echo "Executing: \$CMD"

      # hand off to Java
      exec \$CMD
      EOF
            chmod +x $out/bin/jeveassets
    '';

    meta = with pkgs.lib; {
      description = "Internal stage: script + assets + icon for jEveAssets";
      platforms = [ "x86_64-linux" ];
    };
  };

  # 4) Generate the .desktop entry
  desktopDrv = pkgs.makeDesktopItem {
    name = "jeveassets";
    desktopName = "jEveAssets";
    comment = "EVE Online Asset Manager";
    exec = "${scriptDrv}/bin/jeveassets %U";
    icon = "jeveassets";
    terminal = false;
    categories = [ "Utility" ];
  };

in

# 5) Merge everything into one final output
pkgs.symlinkJoin {
  name = "jeveassets";
  paths = [
    scriptDrv
    desktopDrv
  ];

  meta = with pkgs.lib; {
    description = "jEveAssets – EVE Online asset manager";
    homepage = "https://github.com/GoldenGnu/jeveassets";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ ];
    platforms = [ "x86_64-linux" ];
  };
}
