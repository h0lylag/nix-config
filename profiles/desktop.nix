# Desktop profile - Full desktop workstation configuration
# Use this for relic and similar desktop machines
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./base.nix
    ../modules/tailscale.nix
    ../modules/desktop.nix
    ../modules/podman.nix
  ];

  # Desktop machines get systemd-resolved for VPN compatibility (mullvad, etc.)
  services.resolved.enable = lib.mkDefault true;

  # NetworkManager for desktop convenience
  networking.networkmanager = {
    enable = lib.mkDefault true;
    dns = lib.mkDefault "systemd-resolved";
  };

  # Desktops typically don't need SSH (can override if desired)
  services.openssh.enable = lib.mkDefault false;

  # Desktop firewall is more restrictive by default
  # Hosts can open ports as needed
  networking.firewall = {
    enable = lib.mkDefault true;
    allowedTCPPorts = lib.mkDefault [ ];
    allowedUDPPorts = lib.mkDefault [ ];
  };

  # Enable our user to use input devices for hotkeys, controllers, etc.
  hardware.uinput.enable = lib.mkDefault true;

  # Default desktop user configuration
  # Hosts can extend this with additional groups
  users.users.chris = {
    extraGroups = [
      "input"
      "podman"
      "networkmanager"
    ];
  };
}
