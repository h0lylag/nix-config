# ascension - OVH/OpenStack VPS, initially providing SSH and Tailscale only.
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ../../profiles/base.nix
    ../../profiles/common.nix
  ];

  networking = {
    hostName = "ascension";
    useNetworkd = true;
    useDHCP = false;
  };

  # Preserve the provider's DHCP-supplied /32 address, gateway route and DNS.
  systemd.network.networks."10-uplink" = {
    matchConfig.MACAddress = "fa:16:3e:64:18:62";
    linkConfig.MTUBytes = "1500";
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
    };
  };
  services.resolved.enable = true;

  # The base profile supplies root/chris authorized keys and enables Tailscale.
  services.openssh.settings.PasswordAuthentication = false;

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 8 * 1024;
      priority = 10;
    }
  ];

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    priority = 100;
  };

  system.stateVersion = "26.05";
}
