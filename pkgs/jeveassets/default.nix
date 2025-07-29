{
  pkgs ? import <nixpkgs> { },
}:

pkgs.stdenv.mkDerivation rec {
  pname = "jeveassets";
  version = "8.0.3";

  src = pkgs.fetchzip {
    url = "https://github.com/GoldenGnu/jeveassets/releases/download/jeveassets-${version}/jeveassets-${version}.zip";
    sha256 = "dxVLvDrTLCtBrldJ/gyYTE8rXOOGNO2PGT61aCg9ZyI=";
  };

  buildInputs = [ pkgs.jdk ];

  installPhase = ''
    mkdir -p $out/share/jeveassets

    cp -r * $out/share/jeveassets/

    cat > jeveassets <<EOF
    #!${pkgs.runtimeShell}
    cd $out/share/jeveassets
    export CLASSPATH="jeveassets.jar:jmemory.jar:lib/*"
    HEADLESS_FLAG=""
    [ "\$JEVE_HEADLESS" = "1" ] && HEADLESS_FLAG="-Djava.awt.headless=true"
    [ -z "\$JEVE_XMX" ] && { echo "Error: JEVE_XMX is not set"; exit 1; }
    exec ${pkgs.jdk}/bin/java -Xmx\$JEVE_XMX \$HEADLESS_FLAG -cp "\$CLASSPATH" net.nikr.eve.jeveasset.Main "\$@"
    EOF

    install -Dm755 jeveassets $out/bin/jeveassets
  '';

  meta = with pkgs.lib; {
    description = "jEveAssets - EVE Online asset manager";
    homepage = "https://github.com/GoldenGnu/jeveassets";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ ];
  };
}
