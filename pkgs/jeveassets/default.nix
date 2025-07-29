{
  pkgs,
  java ? pkgs.jdk,
  javaMemory ? "4g",
}:

let
  version = "8.0.3";

  # 1) Upstream binary ZIP
  src = pkgs.fetchzip {
    url = "https://github.com/GoldenGnu/jeveassets/releases/download/jeveassets-${version}/jeveassets-${version}.zip";
    sha256 = "dxVLvDrTLCtBrldJ/gyYTE8rXOOGNO2PGT61aCg9ZyI=";
  };

  # 2) Icon PNG
  icon = pkgs.fetchurl {
    url = "https://wiki.jeveassets.org/_media/wiki/logo.png";
    sha256 = "0y3828ssz7v3hw54099wdcfg66cv2jyb67qr1zbf5wxz16b5i264";
  };

  # 3) scriptDrv: just unpack + wrapper
  scriptDrv = pkgs.stdenv.mkDerivation {
    pname = "jeveassets";
    version = version;

    # JDK needed at runtime to run `java`
    propagatedBuildInputs = [ java ];

    phases = [ "installPhase" ];
    installPhase = ''
                    mkdir -p $out/{bin,share/jeveassets,share/icons/hicolor/64x64/apps}

                    # copy everything (including dot-files)
                    cp -a ${src}/. $out/share/jeveassets

                    # install icon
                    install -Dm644 ${icon} \
                      $out/share/icons/hicolor/64x64/apps/jeveassets.png

                    # Create launcher script
                    cat > jeveassets-launcher <<EOF
                    
      #!${pkgs.runtimeShell}

      XMS="512m"
      XMX="${javaMemory}"

      # assemble and print the Java invocation
      CMD="${java}/bin/java -Xms\$XMS -Xmx\$XMX -jar $out/share/jeveassets/jeveassets.jar \$@"
      echo "Executing: \$CMD"

      # hand off to Java
      exec \$CMD
      EOF

            install -Dm755 jeveassets-launcher $out/bin/jeveassets
    '';
  };

  # 4) .desktop entry
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

# 5) Final bundle via buildEnv
pkgs.buildEnv {
  name = "jeveassets-${version}";
  paths = [
    scriptDrv
    desktopDrv
  ];
  meta = with pkgs.lib; {
    description = "jEveAssets — EVE Online Asset Manager";
    homepage = "https://github.com/GoldenGnu/jeveassets";
    license = licenses.gpl3Plus;
    maintainers = [ maintainers.h0lylag ];
    platforms = platforms.linux;
  };
}
