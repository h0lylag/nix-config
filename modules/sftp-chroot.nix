# Reusable module: SFTP-only chroot users under /srv/www/<user>/html
# Drop at: modules/sftp-chroot.nix and import from your host config.

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.sftpChroot;
  t = lib.types;

  # Build user config with optional password hash and uid
  # Set password later with: sudo passwd <user>
  # Or pre-hash: mkpasswd -m sha-512
  mkUser =
    name: u:
    {
      isSystemUser = true;
      group = cfg.group;
      description = "SFTP-only chroot user";
      shell = "${pkgs.shadow}/bin/nologin";
    }
    // lib.optionalAttrs (u.uid != null) { uid = u.uid; }
    // lib.optionalAttrs (u.passwordHash != null) { hashedPassword = u.passwordHash; };

  # Use the actual nginx user if configured differently
  nginxUser = config.services.nginx.user or "nginx";

  # Build group members list: nginx (if enabled) + additional members
  # Filter to only existing users and deduplicate
  allMembersRaw =
    lib.optionals (cfg.addNginxToGroup && (config.services.nginx.enable or false)) [ nginxUser ]
    ++ cfg.additionalGroupMembers;
  existingUsers = builtins.attrNames (config.users.users or { });
  groupMembers = lib.unique (lib.filter (u: lib.elem u existingUsers) allMembersRaw);

in
{
  options.services.sftpChroot = {
    enable = lib.mkOption {
      type = t.bool;
      default = false;
      description = "Enable SFTP-only chroot users under /srv/www/<user>/html.";
    };

    baseDir = lib.mkOption {
      type = t.str; # use str (not path) so it needn't exist at eval time
      default = "/srv/www";
      description = "Base directory for chroot roots (each user at <baseDir>/<user>).";
    };

    group = lib.mkOption {
      type = t.str;
      default = "sftpusers";
      description = "Primary group for SFTP users and Match Group in sshd_config.";
    };

    umask = lib.mkOption {
      type = t.str;
      default = "0002"; # files 664, dirs 775 inside /html (nice for shared/group read)
      description = "Umask passed to internal-sftp (-u). Octal as string.";
    };

    normalizeHtmlAtBoot = lib.mkOption {
      type = t.bool;
      default = false;
      description = "Recursively normalize html directory permissions at boot (can be slow on large directories).";
    };

    fixChrootPerms = lib.mkOption {
      type = t.bool;
      default = false;
      description = "Enforce (non-recursive) root ownership/perms on chroot parent dirs and per-user chroot roots.";
    };

    logLevel = lib.mkOption {
      type = t.enum [
        "QUIET"
        "FATAL"
        "ERROR"
        "INFO"
        "VERBOSE"
        "DEBUG"
        "DEBUG1"
        "DEBUG2"
        "DEBUG3"
      ];
      default = "ERROR";
      description = "internal-sftp log level. INFO logs all file operations, ERROR logs only failures.";
    };

    # Additional users to add to the SFTP group (e.g., php-fpm, other web servers)
    additionalGroupMembers = lib.mkOption {
      type = t.listOf t.str;
      default = [ ];
      example = [
        "php"
        "www-data"
      ];
      description = "Additional system users to add to the SFTP group so they can read uploaded files.";
    };

    # Convenience: automatically add nginx user if nginx is enabled
    addNginxToGroup = lib.mkOption {
      type = t.bool;
      default = true;
      description = "Automatically add nginx user to sftp group (only if nginx is enabled).";
    };

    # Toggle password auth for SFTP group only (global SSH remains key-only)
    passwordAuth = lib.mkOption {
      type = t.bool;
      default = true;
      description = "If true, enable PasswordAuthentication inside the SFTP Match block (global default remains disabled).";
    };

    # Require each user to have either passwordHash or at least one authorized key.
    requireAuth = lib.mkOption {
      type = t.bool;
      default = true;
      description = "If true, assert that each user has passwordHash or authorizedKeys.";
    };

    users = lib.mkOption {
      type = t.attrsOf (
        t.submodule (
          { name, ... }:
          {
            options = {
              uid = lib.mkOption {
                type = t.nullOr t.int;
                default = null;
              };
              passwordHash = lib.mkOption {
                type = t.nullOr t.str;
                default = null;
              };
              authorizedKeys = lib.mkOption {
                type = t.listOf t.str;
                default = [ ];
              };
            };
          }
        )
      );
      default = { };
      example = {
        sven = {
          passwordHash = "$6$...";
        };
        alice = {
          authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... alice@laptop" ];
        };
      };
      description = "Map of SFTP-only users to create.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Warn about group members that don't exist as users (helps catch typos)
    warnings =
      let
        dropped = lib.subtractLists allMembersRaw groupMembers; # Requested but not added
      in
      lib.optionals (dropped != [ ]) [
        "sftpChroot: additionalGroupMembers not found as users and were ignored: ${lib.concatStringsSep ", " dropped}"
      ];

    # Basic safety: absolute baseDir, and (optionally) require some auth per user
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.baseDir;
        message = "services.sftpChroot.baseDir must be an absolute path.";
      }
      {
        assertion = builtins.match "^[0-7]{3,4}$" cfg.umask != null;
        message = "services.sftpChroot.umask must be a 3-4 digit octal string (e.g. '0002' or '0022').";
      }
    ]
    ++ lib.optionals cfg.requireAuth (
      lib.mapAttrsToList (name: u: {
        assertion = (u.passwordHash != null) || (u.authorizedKeys != [ ]);
        message = "services.sftpChroot.users.${name}: set passwordHash or authorizedKeys (or set requireAuth=false).";
      }) cfg.users
    );

    # Group for SFTP users with web service users as members
    users.groups.${cfg.group} = {
      members = groupMembers;
    };

    # System users (no shells, no home management)
    users.users = lib.mapAttrs (
      name: u:
      (mkUser name u)
      // {
        openssh.authorizedKeys.keys = u.authorizedKeys;
      }
    ) cfg.users;

    # Chroot layout:
    #   /srv                  -> root:root 0755  (chroot parent must be compliant)
    #   /srv/www              -> root:root 0755  (baseDir must be root-owned)
    #   /srv/www/<user>       -> root:root 0755  (chroot root - MUST be non-writable)
    #   /srv/www/<user>/html  -> <user>:sftpusers 02775 (setgid; user/group writable)
    systemd.tmpfiles.rules = [
      "d /srv 0755 root root - -" # Ensure chroot parent exists with correct perms
      "d ${cfg.baseDir} 0755 root root - -"
    ]
    ++ lib.optionals cfg.fixChrootPerms [
      # Non-recursive fix for parent dirs only (safe, fast)
      "z /srv                   0755 root root - -" # non-recursive
      "z ${cfg.baseDir}         0755 root root - -" # non-recursive
    ]
    ++ (lib.flatten (
      lib.mapAttrsToList (
        name: u:
        [
          "d ${cfg.baseDir}/${name}       0755 root root       - -"
          "d ${cfg.baseDir}/${name}/html  02775 ${name} ${cfg.group} - -"
        ]
        ++ lib.optionals cfg.fixChrootPerms [
          # Enforce chroot root ownership (fast, non-recursive)
          "z ${cfg.baseDir}/${name}       0755 root root       - -"
        ]
        ++ lib.optionals cfg.normalizeHtmlAtBoot [
          # Recursively normalize html subtree perms each boot (can be slow on large dirs)
          "Z ${cfg.baseDir}/${name}/html  02775 ${name} ${cfg.group} - -"
        ]
      ) cfg.users
    ));

    # OpenSSH: internal-sftp jail for the group
    services.openssh.enable = lib.mkDefault true;
    services.openssh.openFirewall = lib.mkDefault true;
    services.openssh.settings = {
      # Global defaults: no passwords, key-only (except for SFTP group if enabled)
      PasswordAuthentication = lib.mkDefault false;
      KbdInteractiveAuthentication = lib.mkDefault false; # Disable PAM prompts
      PermitRootLogin = lib.mkDefault "prohibit-password";
    };
    services.openssh.extraConfig = lib.mkAfter ''
      Match Group ${cfg.group}
        ${lib.optionalString cfg.passwordAuth "PasswordAuthentication yes"}
        ChrootDirectory ${cfg.baseDir}/%u
        ForceCommand internal-sftp -d /html -u ${cfg.umask} -f AUTHPRIV -l ${cfg.logLevel}
        X11Forwarding no
        AllowTCPForwarding no
        PermitTunnel no
    '';
  };
}
