final: _prev: {
  # Trayscale before 0.20.0 subscribes to tailscaled's IPN bus with the initial
  # netmap bit, which tailscaled 1.104 rejects with HTTP 400; the window then
  # blocks forever waiting for a first status. Mirrors NixOS/nixpkgs#576958,
  # built from unstable because 0.21.0 needs Go 1.27.2.
  trayscale = final.unstable.trayscale.overrideAttrs (
    finalAttrs: old: {
      version = "0.21.0";

      src = final.fetchFromGitHub {
        owner = "DeedleFake";
        repo = "trayscale";
        tag = "v${finalAttrs.version}";
        hash = "sha256-8Wv+jLkGVpPfvEMVBpliOAJNG6/XVX93q3l9qIChVpg=";
      };

      vendorHash = "sha256-bxiloB4cJHY45nMYczEToCExj3ZlvDKqA7yYAbgGmi4=";

      # dist.sh now fails when the binary was already moved into $out.
      postInstall = ''
        sh ./dist.sh install-data $out
        glib-compile-schemas $out/share/glib-2.0/schemas
      '';

      # 0.21.0 dlopens GTK through purego, which cannot find store paths itself.
      preFixup = old.preFixup + ''
        gappsWrapperArgs+=(--set-default PUREGOTK_LIB_FOLDER ${
          final.unstable.symlinkJoin {
            name = "trayscale-puregotk-lib";
            paths = with final.unstable; [
              cairo
              gdk-pixbuf
              glib.out
              graphene
              gtk4
              libadwaita
              pango.out
            ];
          }
        }/lib)
      '';
    }
  );
}
