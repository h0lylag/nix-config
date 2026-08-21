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
      { ... }:
      {
        imports = [
          ../container-base.nix
          hermes-agent.nixosModules.default
        ];

        _module.args.nixpkgs-unstable = nixpkgs-unstable;

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

          # Discord token and access controls live outside the Nix store.
          # Create this file manually on cortana before restarting Hermes.
          environmentFiles = [ "/var/lib/hermes/discord.env" ];

          settings = {
            model = {
              provider = "openai-codex";
              default = "gpt-5.6-luna";
            };

            agent = {
              reasoning_effort = "medium";
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
