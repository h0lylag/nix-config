{ pkgs, lib, ... }:

{
  # PostgreSQL — local only, peer auth, no passwords needed
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    ensureDatabases = [ "imgcat" ];
    ensureUsers = [
      {
        name = "imgcat";
        ensureDBOwnership = true;
      }
    ];
    authentication = lib.mkOverride 10 ''
      # TYPE  DATABASE  USER      ADDRESS         METHOD
      local   all       postgres                  peer
      local   all       all                       peer
      host    all       all       127.0.0.1/32    scram-sha-256
      host    all       all       ::1/128         scram-sha-256
    '';
  };
}
