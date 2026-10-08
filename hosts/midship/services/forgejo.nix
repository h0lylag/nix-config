# Forgejo - self-hosted Git forge at git.gravemind.sh
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.services.forgejo;
  domain = "git.gravemind.sh";
in
{
  services.forgejo = {
    enable = true;
    # The module defaults to pkgs.forgejo-lts. Database migrations run on start
    # and cannot be downgraded, so keep the slower LTS cadence.

    # Git over SSH shares midship's OpenSSH on port 22, so the service account
    # is the SSH user in clone URLs: ssh://git@git.gravemind.sh/owner/repo.git.
    user = "git";
    group = "git";

    # Upstream recommends SQLite for low-to-moderate activity instances.
    database.type = "sqlite3";
    lfs.enable = true;

    # Daily restore point before unattended upgrades run migrations.
    dump = {
      enable = true;
      type = "tar.zst";
      age = "7d";
    };

    settings = {
      server = {
        DOMAIN = domain;
        ROOT_URL = "https://${domain}/";
        # eve-price-check owns 127.0.0.1:3000; nginx proxies to the socket.
        PROTOCOL = "http+unix";
      };

      service.DISABLE_REGISTRATION = true;
      session.COOKIE_SECURE = true;

      # Upstream's size-limited LRU recommendation for low-activity instances.
      cache.ADAPTER = "twoqueue";
    };
  };

  # The module only creates its account when it is named "forgejo".
  users.users.git = {
    home = cfg.stateDir;
    useDefaultShell = true;
    group = cfg.group;
    isSystemUser = true;
  };
  users.groups.git = { };

  # Run the Forgejo CLI with the service's user, paths and generated app.ini,
  # e.g. `sudo forgejo-manage admin user create --admin ...`.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "forgejo-manage" ''
      exec systemd-run \
        --pty \
        --uid=${cfg.user} \
        --gid=${cfg.group} \
        --working-directory=${cfg.stateDir} \
        --setenv=PATH=${
          lib.makeBinPath [
            cfg.package
            pkgs.git
            pkgs.gnupg
          ]
        } \
        --setenv=HOME=${cfg.stateDir} \
        --setenv=FORGEJO_WORK_DIR=${cfg.stateDir} \
        --setenv=FORGEJO_CUSTOM=${cfg.customDir} \
        --service-type=exec \
        --wait \
        --collect \
        ${lib.getExe cfg.package} "$@"
    '')
  ];
}
