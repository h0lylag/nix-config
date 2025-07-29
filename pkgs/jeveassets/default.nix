{
  pkgs,
  java ? pkgs.jdk,
  javaXms ? "512m",
  javaXmx ? "4g",
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
    pname = "jeveassets-script";
    version = version;

    # JDK needed at runtime to run `java`
    propagatedBuildInputs = [ java ];

    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p $out/{bin,share/jeveassets,share/icons/hicolor/64x64/apps}

      # copy everything
      cp -a ${src}/. $out/share/jeveassets

      # install icon
      install -Dm644 ${icon} $out/share/icons/hicolor/64x64/apps/jeveassets.png

      # Create script
      cat > jeveassets-script <<EOF
      #!${pkgs.runtimeShell}

      # Use user-provided values or defaults
      if [ -z "\$JEVE_XMS" ]; then
        XMS="${javaXms}"
      else
        XMS="\$JEVE_XMS"
      fi

      if [ -z "\$JEVE_XMX" ]; then
        XMX="${javaXmx}"
      else
        XMX="\$JEVE_XMX"
      fi

      # Build JAVA_OPTS using the variables we just set
      JAVA_OPTS="-Xms\$XMS -Xmx\$XMX"

      # Add headless mode if requested
      [ "\$JEVE_HEADLESS" = "1" ] || [ "\$JEVE_HEADLESS" = "true" ] && JAVA_OPTS="\$JAVA_OPTS -Djava.awt.headless=true"

      # Add any additional user options
      [ -n "\$JEVE_JAVA_OPTS" ] && JAVA_OPTS="\$JAVA_OPTS \$JEVE_JAVA_OPTS"

      # Execute Java
      echo "Executing: ${java}/bin/java \$JAVA_OPTS -jar $out/share/jeveassets/jeveassets.jar \$@"
      exec ${java}/bin/java \$JAVA_OPTS -jar $out/share/jeveassets/jeveassets.jar "\$@"
      EOF

      install -Dm755 jeveassets-script $out/bin/jeveassets
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
