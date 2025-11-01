# Reusable NixOS module: SFTP-only chroot users
#
# Creates system users jailed to /srv/www/<user> with uploads landing in /html subdirectory.
# Users see /html as their root when connecting via SFTP.
#
# Usage: Import this module and configure services.sftpChroot.users
# Example:
#   services.sftpChroot = {
#     enable = true;
#     users.alice = { passwordHash = "$6$..."; };
#   };

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.sftpChroot;
  t = lib.types;
  inherit (lib) escapeShellArg;

  # Constructs a system user config for SFTP chroot users
  # These are minimal users: no home directory, no shell access
  # Password can be set via passwordHash or later with: sudo passwd <user>
  # Generate hash with: mkpasswd -m sha-512
  mkUser =
    name: u:
    {
      isSystemUser = true; # System user (not a normal user - no home dir management)
      group = cfg.group; # Primary group (sftpusers by default)
      description = "SFTP-only chroot user";
      shell = "${pkgs.shadow}/bin/nologin"; # No shell access (SFTP only)
    }
    // lib.optionalAttrs (u.uid != null) { uid = u.uid; } # Apply fixed UID if specified
    // lib.optionalAttrs (u.passwordHash != null) { hashedPassword = u.passwordHash; }; # Apply password hash if provided

  # Parent directory of baseDir (e.g., /srv when baseDir=/srv/www)
  # Used to ensure parent exists with correct permissions
  # Guarded against "/" to avoid tmpfiles rules for root directory
  baseParent = builtins.dirOf cfg.baseDir;

  # Resolve the actual nginx user (respects services.nginx.user override)
  # Defaults to "nginx" if nginx service isn't configured
  nginxUser = config.services.nginx.user or "nginx";

  # Extract PHP-FPM pool users for automatic group membership
  # Detection: PHP-FPM is "enabled" when pools are defined (no explicit enable flag exists)
  phpPools = config.services.phpfpm.pools or { };
  phpFpmEnabled = cfg.addPhpFpmToGroup && (phpPools != { });
  phpFpmUsersRaw = lib.optionals phpFpmEnabled (
    let
      vals = lib.attrValues phpPools;
    in
    map (p: p.user or "phpfpm") vals # Extract user from each pool, fallback to "phpfpm"
  );

  # Build the complete list of SFTP group members
  # Sources: nginx user (if enabled) + PHP-FPM pool users + manual additions
  # Filtered to only existing system users and deduplicated
  allMembersRaw =
    lib.optionals (cfg.addNginxToGroup && (config.services.nginx.enable or false)) [ nginxUser ]
    ++ phpFpmUsersRaw
    ++ cfg.additionalGroupMembers;
  existingUsers = builtins.attrNames (config.users.users or { }); # All defined users in the system
  groupMembers = lib.unique (lib.filter (u: lib.elem u existingUsers) allMembersRaw); # Filter to existing + dedup

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
      default = "0002"; # Group writable: files=664, dirs=775 (good for nginx/PHP-FPM to read)
      description = ''
        Umask passed to internal-sftp (-u). Octal string (e.g., "0002" or "0022").
        Controls default permissions for uploaded files:
        - 0002 → files 664, dirs 775 (group writable)
        - 0022 → files 644, dirs 755 (group read-only)
        Automatically overridden to 0022 when readOnlyForWeb=true.
      '';
    };

    readOnlyForWeb = lib.mkOption {
      type = t.bool;
      default = false;
      description = ''
        Secure mode: web servers can read but not write to uploaded files.
        - html directories: 02755 (rwxr-sr-x) instead of 02775 (rwxrwsr-x)
        - umask: forced to 0022 (files 644, dirs 755)
        Use this when nginx/PHP-FPM should only serve files, not modify them.
      '';
    };

    normalizeHtmlAtBoot = lib.mkOption {
      type = t.bool;
      default = false;
      description = ''
        Recursively fix ownership of html directories at boot (chowns to user:group).
        Does NOT change file permissions (safe), only ownership.
        Can be slow on directories with many files. Prefer fixing ownership issues manually.
      '';
    };

    fixChrootPerms = lib.mkOption {
      type = t.bool;
      default = false;
      description = ''
        Enforce root:root ownership on chroot parent directories and per-user chroot roots.
        Non-recursive (safe, fast) - only fixes directory itself, not contents.
        Use this to repair permissions after manual changes or migrations.
      '';
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
      description = ''
        internal-sftp log level (passed via -l flag).
        - ERROR: Only log failures (recommended for production)
        - INFO: Log every file operation (useful for debugging, very verbose)
        - DEBUG/VERBOSE: Protocol-level debugging
        Logs go to syslog facility AUTHPRIV.
      '';
    };

    additionalGroupMembers = lib.mkOption {
      type = t.listOf t.str;
      default = [ ];
      example = [
        "php"
        "www-data"
      ];
      description = ''
        Additional system users to add to the SFTP group.
        Grants these users read (and possibly write) access to uploaded files.
        Non-existent users are ignored with a warning.
        Usually not needed due to automatic nginx/PHP-FPM detection.
      '';
    };

    addNginxToGroup = lib.mkOption {
      type = t.bool;
      default = true;
      description = ''
        Automatically add nginx user to SFTP group when services.nginx.enable = true.
        Allows nginx to serve uploaded files without manual group configuration.
        Set to false if you manage nginx permissions separately.
      '';
    };

    addPhpFpmToGroup = lib.mkOption {
      type = t.bool;
      default = true;
      description = ''
        Automatically add PHP-FPM pool users to SFTP group when pools are defined.
        Extracts user from each pool config (defaults to "phpfpm" if not specified).
        Allows PHP scripts to read uploaded files without manual configuration.
      '';
    };

    passwordAuth = lib.mkOption {
      type = t.bool;
      default = true;
      description = ''
        Enable password authentication for SFTP group users only.
        Global SSH remains key-only (PasswordAuthentication=false).
        Match Group block overrides this for the SFTP group specifically.
        Set to false to require SSH keys for SFTP users too.
      '';
    };

    requireAuth = lib.mkOption {
      type = t.bool;
      default = true;
      description = ''
        Require each SFTP user to have either passwordHash or authorizedKeys defined.
        Prevents accidentally creating users with no authentication method.
        Set to false to allow users without auth (not recommended - you can set password later with passwd).
      '';
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

  config = lib.mkIf cfg.enable (
    let
      # Compute effective values based on readOnlyForWeb toggle
      # Read-only mode: tighter permissions (files 644, dirs 755, group can't write)
      # Normal mode: group writable (files 664, dirs 775, nginx/PHP can write)
      effectiveUmask = if cfg.readOnlyForWeb then "0022" else cfg.umask;
      htmlMode = if cfg.readOnlyForWeb then "02755" else "02775";
      activationCommands = lib.concatMapStringsSep "\n" (
        name:
        let
          escapedUserDir = escapeShellArg "${cfg.baseDir}/${name}";
          escapedHtmlDir = escapeShellArg "${cfg.baseDir}/${name}/html";
        in
        ''
          install -d -m 0755 -o root -g root ${escapedUserDir}
          install -d -m ${htmlMode} -o ${escapeShellArg name} -g ${escapeShellArg cfg.group} ${escapedHtmlDir}
        ''
      ) (lib.attrNames cfg.users);
    in
    {
      # Issue warnings for configuration issues (non-fatal, shown during nixos-rebuild)
      warnings =
        let
          # Users requested in additionalGroupMembers but don't exist in system
          dropped = lib.subtractLists allMembersRaw groupMembers;
        in
        # Warn about typos in additionalGroupMembers
        lib.optionals (dropped != [ ]) [
          "sftpChroot: additionalGroupMembers not found as users and were ignored: ${lib.concatStringsSep ", " dropped}"
        ]
        # Warn when web servers have write access (security awareness)
        # Only warn if: not read-only mode AND group writable AND permissive umask AND group has members
        ++
          lib.optionals
            (!cfg.readOnlyForWeb && htmlMode == "02775" && effectiveUmask != "0022" && groupMembers != [ ])
            [
              "sftpChroot: group members (${lib.concatStringsSep ", " groupMembers}) will have WRITE access in /html (mode ${htmlMode}, umask ${effectiveUmask})."
            ];

      # Validate configuration (hard failures if these don't pass)
      assertions = [
        # baseDir must be absolute path for chroot to work
        {
          assertion = lib.hasPrefix "/" cfg.baseDir;
          message = "services.sftpChroot.baseDir must be an absolute path.";
        }
        # Validate the *effective* umask (after readOnlyForWeb override)
        # This catches invalid umask values even when readOnlyForWeb would override them
        {
          assertion = builtins.match "^[0-7]{3,4}$" effectiveUmask != null;
          message = "services.sftpChroot: effective umask must be 3–4 digit octal (got: ${effectiveUmask}).";
        }
      ]
      # Verify each user has at least one authentication method (if requireAuth=true)
      ++ lib.optionals cfg.requireAuth (
        lib.mapAttrsToList (name: u: {
          assertion = (u.passwordHash != null) || (u.authorizedKeys != [ ]);
          message = "services.sftpChroot.users.${name}: set passwordHash or authorizedKeys (or set requireAuth=false).";
        }) cfg.users
      );

      # Create the SFTP group and populate it with web service users
      # This gives nginx/PHP-FPM read (and possibly write) access to uploaded files
      users.groups.${cfg.group} = {
        members = groupMembers; # Computed list: nginx + PHP-FPM + manual additions
      };

      # Create system users for SFTP access
      # These users are minimal: no home directory, no shell, chrooted to baseDir/<name>
      users.users = lib.mapAttrs (
        name: u:
        (mkUser name u) # Base user config (isSystemUser, group, shell, etc.)
        // {
          openssh.authorizedKeys.keys = u.authorizedKeys; # Inject SSH keys if provided
        }
      ) cfg.users;

      # Create directory structure via systemd-tmpfiles
      # OpenSSH chroot requirements:
      #   - Chroot root (/srv/www/<user>) must be owned by root:root and not writable by user
      #   - All parent directories up to root must be owned by root and not writable by user
      #   - Upload target (/srv/www/<user>/html) can be user-owned and writable
      #
      # Resulting layout:
      #   /srv (or parent of baseDir) -> root:root 0755  (OpenSSH chroot requirement)
      #   /srv/www (baseDir)          -> root:root 0755  (OpenSSH chroot requirement)
      #   /srv/www/<user>             -> root:root 0755  (chroot jail root - MUST be non-writable)
      #   /srv/www/<user>/html        -> <user>:sftpusers 02775 (setgid; user + group writable)
      #
      # Tmpfiles rule types:
      #   d = create directory if missing (doesn't change existing perms)
      #   z = set ownership/perms on directory itself (non-recursive, safe)
      #   Z = recursively set ownership/perms (use carefully - only for ownership with "-" mode)
      systemd.tmpfiles.rules =
        let
          # Create rules for parent directory (e.g., /srv when baseDir=/srv/www)
          # Skip if baseParent is "/" to avoid rules for root filesystem
          parentRules =
            lib.optionals (baseParent != "/") [ "d ${baseParent} 0755 root root - -" ]
            ++ lib.optionals (cfg.fixChrootPerms && baseParent != "/") [
              "z ${baseParent} 0755 root root - -" # Non-recursive fix
            ];
        in
        parentRules
        ++ [
          # Create baseDir (e.g., /srv/www) - always needed
          "d ${cfg.baseDir} 0755 root root - -"
        ]
        ++ lib.optionals cfg.fixChrootPerms [
          # Enforce correct baseDir ownership (non-recursive, safe)
          "z ${cfg.baseDir} 0755 root root - -"
        ]
        ++ (lib.flatten (
          lib.mapAttrsToList (
            name: u:
            [
              # Create chroot root: /srv/www/<user> (root-owned, non-writable by user)
              "d ${cfg.baseDir}/${name}       0755 root root       - -"
              # Create upload target: /srv/www/<user>/html (user-owned, group writable with setgid)
              # htmlMode is 02775 (group writable) or 02755 (group read-only) based on readOnlyForWeb
              "d ${cfg.baseDir}/${name}/html  ${htmlMode} ${name} ${cfg.group} - -"
            ]
            ++ lib.optionals cfg.fixChrootPerms [
              # Enforce chroot root ownership (non-recursive, fast, safe)
              "z ${cfg.baseDir}/${name}       0755 root root       - -"
            ]
            ++ lib.optionals cfg.normalizeHtmlAtBoot [
              # Recursively fix ownership of uploaded files (ownership only, doesn't chmod)
              # The "-" in mode position means: don't change permissions, only ownership
              "Z ${cfg.baseDir}/${name}/html  -    ${name} ${cfg.group} - -"
            ]
          ) cfg.users
        ));

      # Activation script: ensure chroot directories always exist with correct perms
      system.activationScripts.sftpChroot = lib.mkIf (cfg.users != { }) {
        deps = [ "users" ];
        text = ''
          set -euo pipefail
          ${lib.optionalString (baseParent != "/") ''
            install -d -m 0755 -o root -g root ${escapeShellArg baseParent}
          ''}
          install -d -m 0755 -o root -g root ${escapeShellArg cfg.baseDir}
          ${activationCommands}
        '';
      };

      # Configure OpenSSH for SFTP chroot jail
      # Strategy: Global SSH is key-only and secure, SFTP group gets special overrides
      services.openssh.enable = lib.mkDefault true;
      services.openssh.openFirewall = lib.mkDefault true; # Open port 22

      # Where to look for authorized SSH keys
      # .ssh/authorized_keys won't work for chroot users (they have no home dir)
      # Keys are applied via users.users.<name>.openssh.authorizedKeys.keys instead
      services.openssh.authorizedKeysFiles = lib.mkDefault [
        "/etc/ssh/authorized_keys.d/%u" # System-wide per-user keys
        ".ssh/authorized_keys" # Standard location (relative to home/chroot)
      ];

      # Global SSH security settings (apply to all users by default)
      services.openssh.settings = {
        PasswordAuthentication = lib.mkDefault false; # No passwords for SSH (key-only)
        KbdInteractiveAuthentication = lib.mkDefault false; # Disable PAM challenges (no interactive prompts)
        PubkeyAuthentication = lib.mkDefault true; # Enable SSH key authentication
        StrictModes = lib.mkDefault true; # Enforce permission checks on key files
        PermitRootLogin = lib.mkDefault "prohibit-password"; # Root can only login with keys
      };

      # OpenSSH configuration injection
      # Two parts: global subsystem declaration + per-group Match block overrides
      # IMPORTANT: Priority matters - Subsystem must come before Match blocks in sshd_config
      # Do NOT add other "Match Group ${cfg.group}" blocks elsewhere - keep single-sourced here
      services.openssh.extraConfig = lib.mkMerge [
        # Part 1: Global SFTP subsystem (goes at top of config via mkBefore)
        # Uses internal-sftp (built into sshd) instead of external /usr/lib/sftp-server binary
        # This is required for chroot to work (external binary can't access files outside chroot)
        (lib.mkBefore ''
          Subsystem sftp internal-sftp
        '')

        # Part 2: SFTP group-specific overrides (goes at end of config via mkAfter)
        # Match blocks must come last in sshd_config or they'll break subsequent global directives
        (lib.mkAfter ''
          Match Group ${cfg.group}
            ${lib.optionalString cfg.passwordAuth "PasswordAuthentication yes"}
            ChrootDirectory ${cfg.baseDir}/%u
            ForceCommand internal-sftp -d /html -u ${effectiveUmask} -f AUTHPRIV -l ${cfg.logLevel}
            X11Forwarding no
            AllowTCPForwarding no
            PermitTunnel no
        '')
      ];
      # Match block breakdown:
      #   Match Group ${cfg.group}           - Apply these settings only to SFTP group members
      #   PasswordAuthentication yes         - Override global setting (allow passwords for SFTP if enabled)
      #   ChrootDirectory ${cfg.baseDir}/%u  - Jail user to /srv/www/<username>
      #   ForceCommand internal-sftp ...     - Force SFTP protocol (no shell access)
      #     -d /html                         - Start in /html subdirectory (user sees this as root)
      #     -u ${effectiveUmask}             - Set umask for uploaded files (0002 or 0022)
      #     -f AUTHPRIV                      - Log to syslog AUTHPRIV facility
      #     -l ${cfg.logLevel}               - Verbosity (ERROR, INFO, DEBUG, etc.)
      #   X11Forwarding no                   - Disable X11 (not useful for SFTP)
      #   AllowTCPForwarding no              - Disable port forwarding (security hardening)
      #   PermitTunnel no                    - Disable tunneling (security hardening)
    }
  );
}
