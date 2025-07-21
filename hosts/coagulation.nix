{ config, pkgs, ... }:

{
  imports = [
    ../hardware/coagulation.nix
    ../modules/common.nix
    ../modules/tailscale.nix
  ];

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = false;

  networking.hostName = "coagulation";
  networking.networkmanager.enable = true;

  # set static ip
  networking.interfaces.ens18.ipv4.addresses = [
    {
      address = "10.1.1.10";
      prefixLength = 24;
    }
  ];

  networking.defaultGateway = "10.1.1.1";
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
    "10.1.1.1"
  ];

  # minecraft
  services.minecraft-server = {
    enable = false;
    eula = true;
    jvmOpts = "-Xms6G -Xmx12G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true";
    dataDir = "/var/lib/minecraft";
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    22
    80
    443
    25565
  ];
  networking.firewall.allowedUDPPorts = [
    22
    80
    443
    25565
  ];

  system.stateVersion = "24.05";

}
