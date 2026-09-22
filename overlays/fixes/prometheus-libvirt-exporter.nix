_final: prev: {
  # The nixpkgs package advertises the wrong binary name to NixOS services.
  # Remove once its upstream meta.mainProgram is libvirt-exporter.
  prometheus-libvirt-exporter = prev.prometheus-libvirt-exporter.overrideAttrs (old: {
    meta = old.meta // {
      mainProgram = "libvirt-exporter";
    };
  });
}
