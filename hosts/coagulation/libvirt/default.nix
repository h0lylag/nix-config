# Default libvirt configuration
{
  pkgs,
  NixVirt,
  ...
}:

let
  # User/Group for QEMU
  qemuUser = "qemu-libvirtd";
  qemuGroup = "kvm";

  swtpmVar = "/var/lib/libvirt/swtpm";
  swtpmRun = "/run/libvirt/swtpm";
  imagesPath = "/var/lib/libvirt/images";
in
{
  imports = [
    ./win10-1/default.nix
  ];

  _module.args = {
    inherit qemuUser qemuGroup;
  };

  # ---------------------------------------------------------
  # Unprivileged QEMU Configuration
  # ---------------------------------------------------------
  virtualisation.libvirt.enable = true;
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      swtpm.enable = true;
      ovmf.enable = true;
    };
  };

  # ---------------------------------------------------------
  # Permission Enforcement
  # ---------------------------------------------------------
  # Ensure the unprivileged qemu user can access TPM state/sockets.
  # This avoids permission errors when 'runAsRoot = false'.
  systemd.tmpfiles.rules = [
    "Z ${swtpmVar} 0750 ${qemuUser} ${qemuGroup} -"
    "d ${swtpmRun} 0750 ${qemuUser} ${qemuGroup} -"
    "d ${imagesPath} 0755 ${qemuUser} ${qemuGroup} -"
  ];

  environment.variables.LIBVIRT_DEFAULT_URI = "qemu:///system";

  virtualisation.libvirt.connections."qemu:///system" = {
    domains = [
    ];
    pools = [
      {
        definition = NixVirt.lib.pool.writeXML {
          name = "default";
          uuid = "9a865e95-8976-4178-878b-c4d5aba0e2a3";
          type = "dir";
          target = {
            path = imagesPath;
          };
        };
      }
    ];
  };
}
