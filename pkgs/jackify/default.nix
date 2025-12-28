{
  appimageTools,
  fetchurl,
  runCommand,
  buildFHSEnv,
  pkgs,
  ...
}:

let
  pname = "jackify";
  version = "0.2.0.5";
  src = fetchurl {
    url = "https://github.com/Omni-guides/Jackify/releases/download/v${version}/Jackify.AppImage";
    sha256 = "6ae3d39bd11d8cee8df0f36377a5e21e4184c5fbe92437afa062ca0eb7c3b622";
  };
  appimageContents = appimageTools.extractType2 { inherit pname version src; };
  patchedContents = runCommand "${pname}-patched-src" { } ''
    cp -r ${appimageContents} $out
    chmod -R u+w $out
    sed -i "s/def _ensure_protocol_registered(self) -> bool:/def _ensure_protocol_registered(self) -> bool:\\n        return True/" $out/opt/jackify/backend/services/nexus_oauth_service.py

    # Patch protontricks_handler.py to clear PYTHONPATH before calling protontricks
    # This prevents the AppImage's bundled VDF library (older) from conflicting with the system's protontricks (newer)
    sed -i "s/env = self._get_clean_subprocess_env()/env = self._get_clean_subprocess_env(); env.pop('PYTHONPATH', None); env.pop('LD_LIBRARY_PATH', None)/g" $out/opt/jackify/backend/handlers/protontricks_handler.py
  '';
in
buildFHSEnv (
  appimageTools.defaultFhsEnvArgs
  // {
    name = pname;
    targetPkgs =
      pkgs:
      (appimageTools.defaultFhsEnvArgs.targetPkgs pkgs)
      ++ [
        pkgs.zstd
        pkgs.xdg-utils
        pkgs.protontricks
        pkgs.winetricks
        pkgs.cabextract
        pkgs.wget
        pkgs.pcre2
        pkgs.freetype
        pkgs.unzip
        pkgs.file
        pkgs.which
        pkgs.gnused
        pkgs.gawk
        pkgs.coreutils
        pkgs.libidn2
        pkgs.libpsl
        pkgs.lz4
      ];
    runScript = "${patchedContents}/AppRun";

    # Manually handle desktop integration since we lost wrapType2 features
    extraInstallCommands = ''
      install -m 444 -D ${appimageContents}/com.jackify.app.desktop $out/share/applications/jackify.desktop
      install -m 444 -D ${appimageContents}/com.jackify.app.png \
        $out/share/icons/hicolor/512x512/apps/jackify.png
      substituteInPlace $out/share/applications/jackify.desktop \
        --replace 'Icon=com.jackify.app' 'Icon=jackify' \
        --replace 'Terminal=true' 'Terminal=false' \
        --replace 'Exec=jackify' 'Exec=jackify %u'
      echo "MimeType=x-scheme-handler/jackify;" >> $out/share/applications/jackify.desktop
    '';
  }
)
