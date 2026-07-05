{
  config,
  pkgs,
  lib,
  ...
}:

{
  services.redis.servers.prism = {
    enable = true;

    # Listen on TCP for Celery and explicit Prism cache/session URLs.
    # Keep the Unix socket available for REDIS_URL-compatible app defaults.
    port = 6379;
    bind = "127.0.0.1";
    unixSocket = "/run/redis-prism/redis.sock";
    unixSocketPerm = 660;

    settings = {
      maxmemory = "2gb";
      maxmemory-policy = "noeviction";
      save = lib.mkForce "";
      appendonly = "yes";
      appendfsync = "everysec";
      loglevel = "notice";
      databases = 16;
    };
  };

  # Add prism user to redis-prism group so it can access the socket.
  users.users.prism.extraGroups = [ "redis-prism" ];
}
