{ pkgs, ... }:

{
  services.postgresql = {
    enable = true;
    enableTCPIP = true;
    package = pkgs.postgresql_16;
    dataDir = "/var/lib/postgresql/16";
    settings = {
      listen_addresses = "*";
    };
    authentication = pkgs.lib.mkOverride 10 ''
      # Allow local connections for maintenance and services
      local   all   postgres              peer
      local   all   all                   peer
      host    all   all   127.0.0.1/32    scram-sha-256
      host    all   all   ::1/128         scram-sha-256

      # Allow remote connections from specific hosts
      # Use tailscale magicDNS or IPs as needed
      host    all   all   relic.tail97ca.ts.net           scram-sha-256
      host    all   all   lockout.tail97ca.ts.net         scram-sha-256
      host    all   all   coagulation.tail97ca.ts.net     scram-sha-256
    '';
  };
}
