{ pkgs, NixVirt, ... }:

{
  imports = [
    ./win10-1/default.nix
  ];

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
      ovmf = {
        enable = true;
        packages = [ pkgs.OVMFFull.fd ];
      };

    };
  };

  virtualisation.libvirt.connections."qemu:///system" = {
    domains = [
    ];
    pools = [
      {
        definition = NixVirt.lib.pool.writeXML {
          name = "default";
          uuid = "9a865e95-8976-4178-878b-c4d5aba0e2a3"; # Fixed UUID
          type = "dir";
          target = {
            path = "/var/lib/libvirt/images";
          };
        };
      }
    ];
  };
}
