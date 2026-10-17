{
  config,
  eve-ops-hub,
  lib,
  pkgs,
  ...
}:

let
  databaseUrlFile = "${config.services.eve-ops-hub.stateDirectory}/database-url";
in
{
  # The upstream module owns the migrate, web, worker, backup and static-data units.
  imports = [ eve-ops-hub.nixosModules.default ];

  services.eve-ops-hub = {
    enable = true;
    # Upstream's nixpkgs pin provides the rustc 1.98 that the workspace requires.
    package = eve-ops-hub.packages.${pkgs.stdenv.hostPlatform.system}.default;
    publicUrl = "https://ops.gravemind.sh";
    # eve-price-check already listens on the module's default port.
    listenAddress = "127.0.0.1:3100";
    inherit databaseUrlFile;
    keyringFile = config.sops.secrets.eve-ops-hub-application-keys.path;
    ssoClientIdFile = config.sops.secrets.eve-ops-hub-sso-client-id.path;
    ssoClientSecretFile = config.sops.secrets.eve-ops-hub-sso-client-secret.path;
    recoveryReference = "secrets/eve-ops-hub.yaml in github.com/h0lylag/nix-config; local recovery sets only";
  };

  # localDatabase would define services.postgresql.package a second time, so
  # provision the database on midship's shared PostgreSQL 18 server directly.
  services.postgresql = {
    ensureDatabases = [ "eve-ops-hub" ];
    ensureUsers = [
      {
        name = "eve-ops-hub";
        ensureDBOwnership = true;
      }
    ];
  };

  # The ensure* clauses run in postgresql-setup.service, which postgresql.target covers.
  systemd.services =
    lib.genAttrs
      [
        "eve-ops-hub-migrate"
        "eve-ops-hub-static-data"
        "eve-ops-hub-backup"
      ]
      (_: {
        after = [ "postgresql.target" ];
        requires = [ "postgresql.target" ];
      });

  # Peer authentication needs no password, so this URL is not secret.
  systemd.tmpfiles.rules = [
    "f+ ${databaseUrlFile} 0400 eve-ops-hub eve-ops-hub - postgresql://eve-ops-hub@localhost/eve-ops-hub?host=/run/postgresql"
  ];

  sops.secrets.eve-ops-hub-application-keys = {
    sopsFile = ../../../secrets/eve-ops-hub.yaml;
    key = "application-keys";
    owner = "eve-ops-hub";
    group = "eve-ops-hub";
    mode = "0400";
    restartUnits = [ "eve-ops-hub-migrate.service" ];
  };

  sops.secrets.eve-ops-hub-sso-client-id = {
    sopsFile = ../../../secrets/eve-ops-hub.yaml;
    key = "sso-client-id";
    owner = "eve-ops-hub";
    group = "eve-ops-hub";
    mode = "0400";
    restartUnits = [ "eve-ops-hub-migrate.service" ];
  };

  sops.secrets.eve-ops-hub-sso-client-secret = {
    sopsFile = ../../../secrets/eve-ops-hub.yaml;
    key = "sso-client-secret";
    owner = "eve-ops-hub";
    group = "eve-ops-hub";
    mode = "0400";
    restartUnits = [ "eve-ops-hub-migrate.service" ];
  };
}
