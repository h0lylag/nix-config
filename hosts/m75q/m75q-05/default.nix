# m75q-05 - Lenovo ThinkCentre M75q (Ryzen 5 PRO 3400GE)
{ inputs, den, ... }:
{
  den.hosts.x86_64-linux.m75q-05.users.chris = { };

  den.aspects.m75q-05 = {
    includes = [ den.aspects.m75q ];
    nixos.imports = [
      (
        { ... }:
        {
          imports = [
            ./hardware-configuration.nix
            ./disko.nix
          ];

          networking.interfaces.enp3s0f0.ipv4.addresses = [
            {
              address = "10.1.1.35";
              prefixLength = 24;
            }
          ];

          system.stateVersion = "26.05";
        }
      )
      inputs.disko.nixosModules.disko
    ];
  };
}
