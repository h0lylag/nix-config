_final: prev: {
  linuxPackages_latest = prev.linuxPackages_latest.extend (
    _kfinal: kprev: {
      # Kernel 7.2's modules_install runs depmod into $out, colliding with the
      # kernel's own index files in the modules tree. Backport NixOS/nixpkgs#575861;
      # remove once nixpkgs-unstable includes it.
      v4l2loopback = kprev.v4l2loopback.overrideAttrs (old: {
        preBuild = "";
        installFlags = (old.installFlags or [ ]) ++ [
          "DEPMOD=true"
          "INSTALL_MOD_PATH=${placeholder "out"}"
        ];
      });
    }
  );
}
