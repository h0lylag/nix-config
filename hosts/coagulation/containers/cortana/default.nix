# Cortana - Hermes Agent container
{
  nixpkgs-unstable,
  hermes-agent,
  ...
}:

{
  containers.cortana = {
    autoStart = true;
    enableTun = true;
    privateNetwork = true;
    # No host storage is bind-mounted; keep container UIDs/GIDs private too.
    privateUsers = "pick";
    hostBridge = "br0";

    config =
      { config, pkgs, ... }:
      let
        homelabDataCollector = pkgs.callPackage ../../../../pkgs/homelab-data-collector/package.nix { };
      in
      {
        imports = [
          ../container-base.nix
          hermes-agent.nixosModules.default
        ];

        _module.args.nixpkgs-unstable = nixpkgs-unstable;

        sops.secrets.cortana-env = {
          sopsFile = ../../../../secrets/cortana.env;
          format = "dotenv";
          owner = "hermes";
          group = "hermes";
          mode = "0400";
        };

        networking.interfaces.eth0.useDHCP = false;
        networking.interfaces.eth0.ipv4.addresses = [
          {
            address = "10.1.1.19";
            prefixLength = 24;
          }
        ];

        services.hermes-agent = {
          enable = true;
          addToSystemPackages = true;

          # Include messaging adapters; remove this group for CLI-only use.
          extraDependencyGroups = [ "messaging" ];
          extraPackages = [ homelabDataCollector ];

          environmentFiles = [ config.sops.secrets."cortana-env".path ];

          settings = {
            model = {
              provider = "openai-codex";
              default = "gpt-5.6-luna";
            };

            agent = {
              reasoning_effort = "light";
            };

            terminal = {
              backend = "local";
              timeout = 180;
            };

            approvals = {
              mode = "manual";
              cron_mode = "deny";
            };
          };

          workingDirectory = "/var/lib/hermes/workspace";
        };

        # The service user owns its state; allow the SSH user to use the
        # managed CLI and inspect the same state directory.
        users.users.chris.extraGroups = [ "hermes" ];

      };
  };
}
