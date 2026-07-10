# 5teak - general-purpose NixOS container
{
  config,
  pkgs,
  lib,
  nixpkgs-unstable,
  sops-nix,
  ...
}:

let
  deployment = config.services.prismReleaseDeployment;
  releaseDataHostPath = "/var/lib/5teak-prism-releases";
  releaseDataContainerPath = "/var/lib/prism-releases";
in
{
  options.services.prismReleaseDeployment = {
    ciAuthorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "ssh-ed25519 AAAAC3Nza... prism-release-ci" ];
      description = ''
        Public SSH keys accepted by the key-only Prism release upload account.
        Supply this in deployment configuration; never put a private key here.
      '';
    };

    magicDnsName = lib.mkOption {
      type = lib.types.str;
      default = "5teak";
      example = "5teak.example-tailnet.ts.net";
      description = ''
        Tailscale MagicDNS name that release CI uses for SFTP. Tailscale ACLs
        must separately restrict the CI tag to this host on TCP port 22.
      '';
    };
  };

  config = {
    services.prismReleaseDeployment.ciAuthorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG9NHsBpx/YIdpCKZwAKmfQ9U2XC7LX8MZG1YAvXaByI prism-release-ci"
    ];

    warnings = lib.optional (deployment.ciAuthorizedKeys == [ ]) ''
      Prism release SFTP is key-only but has no authorized keys. Set
      services.prismReleaseDeployment.ciAuthorizedKeys before enabling CI uploads.
    '';

    # Enable container support
    boot.enableContainers = true;

    # Keep release artifacts outside the container root so container recreation
    # cannot discard incoming, published, or release-state data.
    systemd.tmpfiles.rules = [
      "d ${releaseDataHostPath} 0755 root root - -"
    ];

    containers."5teak" = {
      autoStart = true;
      enableTun = true;
      privateNetwork = true;
      hostBridge = "br0";

      bindMounts.${releaseDataContainerPath} = {
        hostPath = releaseDataHostPath;
        isReadOnly = false;
      };

      config =
        { config, pkgs, ... }:
        {
          imports = [
            ../container-base.nix
            ../../../../modules/sftp-chroot.nix
            sops-nix.nixosModules.sops
            ./services/postgresql.nix
            ./services/redis.nix
            ./services/prism-django.nix
            ./services/nginx.nix
            ./services/discord-relay.nix
            ./services/steak-bot.nix
          ];
          _module.args.nixpkgs-unstable = nixpkgs-unstable;

          services.sftpChroot = {
            enable = true;
            baseDir = "${releaseDataContainerPath}/sftp";
            group = "prism-release-upload";
            uploadDirectory = "incoming";
            uploadDirectoryMode = "02770";
            umask = "0007";
            passwordAuth = false;
            addNginxToGroup = false;
            addPhpFpmToGroup = false;
            additionalGroupMembers = [ "prism" ];
            normalizeHtmlOwnership = true;
            logLevel = "ERROR";
            users.prism-release-ci = {
              uid = 5101;
              authorizedKeys = deployment.ciAuthorizedKeys;
            };
          };

          # These IDs own files on the host bind mount and must remain stable
          # when the container is recreated.
          users.groups.prism-release-upload.gid = 5101;

          environment.etc."prism-release/deployment.env" = {
            mode = "0444";
            text = ''
              PRISM_RELEASE_SFTP_HOST=${deployment.magicDnsName}
              PRISM_RELEASE_SFTP_PORT=22
              PRISM_RELEASE_SFTP_USER=prism-release-ci
              PRISM_RELEASE_SFTP_INCOMING=/incoming
            '';
          };

          sops.age.generateKey = true;
          sops.age.keyFile = "/var/lib/sops-nix/key.txt";

          networking.interfaces.eth0.useDHCP = false;
          networking.interfaces.eth0.ipv4.addresses = [
            {
              address = "10.1.1.18";
              prefixLength = 24;
            }
          ];

          users.users.carter = {
            isNormalUser = true;
            initialPassword = "carter";
            extraGroups = [ "wheel" ];
          };

          environment.systemPackages = with pkgs; [
            age
          ];

        };
    };
  };
}
