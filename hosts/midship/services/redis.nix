{
  config,
  pkgs,
  lib,
  ...
}:

{
  services.redis.servers.prism = {
    enable = true;

    # Use Unix socket instead of TCP for better security and performance
    # Socket will be at /run/redis-prism/redis.sock
    port = 0; # Disable TCP listener entirely
    unixSocket = "/run/redis-prism/redis.sock";
    unixSocketPerm = 660; # Owner + group can read/write

    # User defaults to "redis-prism" and is auto-created by NixOS

    # Memory management
    settings = {
      # Maximum memory usage (256MB - about 3% of 8GB RAM)
      maxmemory = "256mb";

      # Eviction policy: Remove least recently used keys when memory limit hit
      # Good for caching - keeps hot data in memory
      maxmemory-policy = "allkeys-lru";

      # Disable RDB snapshots (cache-only mode, no persistence to disk)
      # Redis will be fast, ephemeral cache
      save = lib.mkForce "";

      # Disable AOF (Append Only File) persistence
      appendonly = "no";

      # Logging
      loglevel = "notice";

      # Performance tuning
      # Number of databases (0-15)
      databases = 16;
    };
  };

  # Add prism user to redis-prism group so it can access the socket
  users.users.prism.extraGroups = [ "redis-prism" ];
}
