{ ... }:
{
  den.aspects.agent-bus = {
    nixos =
      { lib, pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.local.agent-bus ];

        users.users.chris.extraGroups = [ "redis-agent-bus" ];

        services.redis.servers.agent-bus = {
          enable = lib.mkDefault true;
          port = 0;
          openFirewall = false;
          unixSocket = "/run/redis-agent-bus/redis.sock";
          unixSocketPerm = 660;
          appendOnly = true;
          appendFsync = lib.mkDefault "everysec";
          settings = {
            maxmemory = lib.mkDefault "128mb";
            maxmemory-policy = "noeviction";
          };
        };
      };
  };
}
