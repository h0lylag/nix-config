{
  config,
  pkgs,
  lib,
  ...
}:

{
  services.redis.servers.prism = {
    enable = true;

    # Listen on both TCP (for Celery) and Unix socket (for Django cache)
    # Celery doesn't support Unix sockets, needs TCP.
    port = 6379;
    bind = "127.0.0.1";
    unixSocket = "/run/redis-prism/redis.sock";
    unixSocketPerm = 660;

    settings = {
      maxmemory = "256mb";
      maxmemory-policy = "allkeys-lru";
      save = lib.mkForce "";
      appendonly = "no";
      loglevel = "notice";
      databases = 16;
    };
  };

  # Add prism user to redis-prism group so it can access the socket.
  users.users.prism.extraGroups = [ "redis-prism" ];
}
