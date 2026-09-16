{ inputs, den, ... }:
{
  den.aspects.workstation.includes = [
    den.aspects.plasma
    den.aspects.pipewire
    den.aspects.podman
  ];
  # Opted-in Den users receive the account settings for this machine role.
  den.aspects.workstation.user = {
    extraGroups = [
      "podman"
      "networkmanager"
    ];
    subUidRanges = [
      {
        startUid = 100000;
        count = 65536;
      }
    ];
    subGidRanges = [
      {
        startGid = 100000;
        count = 65536;
      }
    ];
  };
  den.aspects.workstation.nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      command-code = pkgs.callPackage ../../pkgs/command-code/package.nix { };
    in

    {
      # Keep TeamSpeak's local package available as pkgs.teamspeak3, like the
      # upstream overlay integration, without importing its flake.
      nixpkgs.overlays = [ (import ../../pkgs/teamspeak3/overlay.nix) ];

      # Workstation machines get systemd-resolved for VPN compatibility (mullvad, etc.)
      services.resolved.enable = lib.mkDefault true;

      # NetworkManager for desktop convenience
      networking.networkmanager = {
        enable = lib.mkDefault true;
        dns = lib.mkDefault "systemd-resolved";
      };

      # Workstation firewall is more restrictive by default
      # Hosts can open ports as needed
      networking.firewall = {
        enable = lib.mkDefault true;
        allowedTCPPorts = lib.mkDefault [ ];
        allowedUDPPorts = lib.mkDefault [ ];
      };

      # Enable our user to use input devices for hotkeys, controllers, etc.
      hardware.uinput.enable = lib.mkDefault true;

      # Hardware configuration for graphics
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };

      # Printing support
      services.printing.enable = lib.mkDefault true;
      services.avahi = {
        enable = lib.mkDefault true;
        nssmdns4 = lib.mkDefault true;
        openFirewall = lib.mkDefault true;
      };

      # Fonts
      fonts.packages = with pkgs; [
        nerd-fonts.roboto-mono
      ];

      # Flatpak support
      xdg.portal.enable = true;
      services.flatpak.enable = lib.mkDefault true;

      # Flatpak natively discovers statically configured system remotes here.
      environment.etc."flatpak/remotes.d/flathub.flatpakrepo".source = pkgs.fetchurl {
        url = "https://dl.flathub.org/repo/flathub.flatpakrepo";
        hash = "sha256-M3HdJQ5h2eFjNjAHP+/aFTzUQm9y9K+gwzc64uj+oDo=";
      };

      # Programs with NixOS integration
      programs.firefox.enable = lib.mkDefault true;
      programs.gpu-screen-recorder.enable = lib.mkDefault true;

      programs.virt-manager.enable = lib.mkDefault true;

      # GnuPG agent
      services.pcscd.enable = true;
      programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
      };

      # Chrome/Chromium with Wayland backend
      environment.sessionVariables.NIXOS_OZONE_WL = "1";

      # Workstation packages
      environment.systemPackages = with pkgs; [

        (chromium.override {
          enableWideVine = false;
        })

        gh
        lm_sensors
        file
        ntfs3g
        filezilla
        mpv
        vlc
        jellyfin-media-player
        gpu-screen-recorder-gtk
        yt-dlp
        simple-scan
        kdePackages.kdenlive
        kdePackages.kcalc
        kdePackages.kolourpaint
        python313Packages.tkinter
        python313Packages.requests
        terminator
        vscode
        qbittorrent
        (pkgs.libreoffice-stable or pkgs.libreoffice-fresh)
        wineWow64Packages.stable
        winetricks
        signal-desktop
        teamspeak3
        command-code
        trayscale
        poppler-utils
        img2pdf
        distrobox
        asciinema
        inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
        nix-update
        patchelf
        mcp-nixos
        thunderbird
        birdtray
        bitwarden-desktop
      ];
    };
}
