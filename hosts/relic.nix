{
  config,
  pkgs,
  ...
}:

{
  imports = [
    ../hardware/relic.nix
    ../modules/common.nix
    ../modules/tailscale.nix
    ../modules/desktop.nix
    ../modules/star-citizen.nix
  ];

  # Bootloader and kernel
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages;

  # enable our user to use input devices - read keyboards, mice, etc for hotkeys
  hardware.uinput.enable = true;
  users.users.chris = {
    extraGroups = [
      "input"
    ];
  };

  # Host/network basics
  networking.hostName = "relic";
  networking.networkmanager.enable = true;

  # ASUS X670E-F bullshit 'fixes' (they dont fix it)
  boot.blacklistedKernelModules = [ "mt7921e" ];
  boot.kernelParams = [
    "pcie_port_pm=off"
    "pcie_aspm.policy=performance"
  ];

  # More forgiving NFS mounts (avoid UI hangs):
  # - x-systemd.automount + noauto: mount on first access instead of at boot
  # - x-systemd.idle-timeout=1min: auto unmount when idle to release hangs
  # - nofail: don't drop to emergency shell if server unavailable
  # - soft,timeo=150,retrans=2: fail RPCs instead of hard blocking (suitable for mostly read / casual access)
  # - bg: retry in background
  # - vers=4.2 (adjust if needed)
  # NOTE: For critical write integrity remove 'soft'
  fileSystems."/mnt/hdd-pool/main" = {
    device = "10.1.1.5:/mnt/hdd-pool/main";
    fsType = "nfs";
    options = [
      "rw"
      "vers=4.2"
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=1min"
      "nofail"
      "soft"
      "timeo=150" # (1/10th sec units) => 15s RPC timeout
      "retrans=2"
      "bg"
      # "fsc"           # enable FS-Cache if desired (needs cachefilesd service)
    ];
  };

  fileSystems."/mnt/nvme-pool/scratch" = {
    device = "10.1.1.5:/mnt/nvme-pool/scratch";
    fsType = "nfs";
    options = [
      "rw"
      "vers=4.2"
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=2min"
      "nofail"
      "soft"
      "timeo=100" # 10s for scratch a bit faster fail
      "retrans=2"
      "bg"
    ];
  };

  services.open-webui.enable = true;
  services.ollama = {
    enable = true;
    acceleration = "rocm"; # rocm for AMD GPUs, cuda for NVIDIA GPUs
    loadModels = [ "gpt-oss:latest" ]; # declare models to load https://ollama.com/library
  };

  services.openssh.enable = false;

  # Firewall
  networking.firewall.allowedTCPPorts = [ ];
  networking.firewall.allowedUDPPorts = [ ];

  # Don't fuck with it
  system.stateVersion = "25.05";

}
