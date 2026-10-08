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

    user = "git";
    group = "git";

    database.type = "sqlite3";
    lfs.enable = true;

    dump = {
      enable = true;
      type = "tar.zst";
      age = "7d";
    };

    settings = {
      server = {
        DOMAIN = domain;
        ROOT_URL = "https://${domain}/";
        PROTOCOL = "http+unix";
      };

      service = {
        # Sign-up only through external sources, i.e. the GitHub OAuth2 source
        DISABLE_REGISTRATION = false;
        ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
        # Contributors only need forks and pull requests.
        DEFAULT_ALLOW_CREATE_ORGANIZATION = false;
      };
      # OpenID sign-up otherwise follows DISABLE_REGISTRATION and accepts any provider.
      openid = {
        ENABLE_OPENID_SIGNIN = false;
        ENABLE_OPENID_SIGNUP = false;
      };
      # One-click accounts named after the GitHub username. If the name or email
      # already exists, Forgejo asks to sign in to that account to link it.
      oauth2_client.ENABLE_AUTO_REGISTRATION = true;

      session.COOKIE_SECURE = true;

      cache.ADAPTER = "twoqueue";
    };
  };

  users.users.git = {
    home = cfg.stateDir;
    useDefaultShell = true;
    group = cfg.group;
    isSystemUser = true;
  };
  users.groups.git = { };

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
