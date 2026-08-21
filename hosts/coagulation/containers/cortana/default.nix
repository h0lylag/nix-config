# Cortana - Hermes Agent container
{
  config,
  pkgs,
  lib,
  nixpkgs-unstable,
  hermes-agent,
  sops-nix,
  ...
}:

let
  cortanaSoul = "IyBTT1VMLm1kCgpZb3UgYXJlIENvcnRhbmEsIGEgY29uY2lzZSwgcHJhY3RpY2FsIGhvbWVsYWIgb3BlcmF0aW9ucyBhc3Npc3RhbnQuCgpQcmVmZXIgcmVhZC1vbmx5IGluc3BlY3Rpb24uIEV4cGxhaW4gcHJvcG9zZWQgY2hhbmdlcywgYW5kIGFzayBmb3IgY29uZmlybWF0aW9uIGJlZm9yZSBkZXN0cnVjdGl2ZSBvciBleHRlcm5hbGx5IHZpc2libGUgYWN0aW9ucy4KClNwZWFrIHdpdGggdW5kZXJzdGF0ZWQgY29uZmlkZW5jZSBhbmQgZHJ5IHdpdC4gQmUgc2hhcnAsIGNvbXBvc2VkLCBvY2Nhc2lvbmFsbHkgcGxheWZ1bCwgYW5kIHByb2FjdGl2ZS4gQXZvaWQgZmlsbGVyLCBjaGVlcmxlYWRpbmcsIGFuZCBjb3Jwb3JhdGUgbGFuZ3VhZ2UuCg==";
in
{
  containers.cortana = {
    autoStart = true;
    enableTun = true;
    privateNetwork = true;
    hostBridge = "br0";

    config =
      { config, pkgs, ... }:
      {
        imports = [
          ../container-base.nix
          hermes-agent.nixosModules.default
          sops-nix.nixosModules.sops
        ];

        _module.args.nixpkgs-unstable = nixpkgs-unstable;

        networking.interfaces.eth0.useDHCP = false;
        networking.interfaces.eth0.ipv4.addresses = [
          {
            # .8 and .10-.18 are already assigned to other containers.
            # Verify .19 is free outside the repository before deployment.
            address = "10.1.1.19";
            prefixLength = 24;
          }
        ];

        # Hermes state is kept in the container's persistent root at
        # /var/lib/hermes. Keep credentials outside the Nix store; create this
        # file after the container's SOPS age key is available.
        sops.age.generateKey = true;
        sops.age.keyFile = "/var/lib/sops-nix/key.txt";

        services.hermes-agent = {
          enable = true;
          addToSystemPackages = true;
          environmentFiles = [ "/var/lib/hermes/env" ];

          # Include messaging adapters; remove this group for CLI-only use.
          extraDependencyGroups = [ "messaging" ];

          settings = {
            # Replace this model if the credentials in /var/lib/hermes/env use
            # another provider or model.
            model = "anthropic/claude-sonnet-4";

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

        # Hermes loads its primary identity from $HERMES_HOME/SOUL.md.
        # Keep the readable text out of the repository and decode it directly
        # into Hermes' persistent state during activation.
        system.activationScripts."hermes-agent-soul" =
          lib.stringAfter
            [
              "hermes-agent-setup"
            ]
            ''
              install -d -o hermes -g hermes -m 0770 \
                /var/lib/hermes/.hermes

              printf '%s' '${cortanaSoul}' \
                | ${pkgs.coreutils}/bin/base64 --decode \
                > /var/lib/hermes/.hermes/SOUL.md

              chown hermes:hermes /var/lib/hermes/.hermes/SOUL.md
              chmod 0660 /var/lib/hermes/.hermes/SOUL.md
            '';

        # The service user owns its state; allow the SSH user to use the
        # managed CLI and inspect the same state directory.
        users.users.chris.extraGroups = [ "hermes" ];

        systemd.tmpfiles.rules = [
          "f /var/lib/hermes/env 0600 hermes hermes - -"
        ];

        # Do not repeatedly restart a service until credentials have been
        # provisioned in /var/lib/hermes/env.
        systemd.services.hermes-agent.serviceConfig.ConditionFileNotEmpty = "/var/lib/hermes/env";
      };
  };
}
