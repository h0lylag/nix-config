{
  config,
  pkgs,
  lib,
  ...
}:

{
  services.redis.servers.prism-v1 = {
    enable = true;

    # Listen on TCP for Celery and explicit Prism cache/session URLs.
    # Keep the Unix socket available for REDIS_URL-compatible app defaults.
    port = 6379;
    bind = "127.0.0.1";
    unixSocket = "/run/redis-prism-v1/redis.sock";
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
}
