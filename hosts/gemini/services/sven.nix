# SFTP-only chrooted user for Sven
{
  config,
  pkgs,
  lib,
  ...
}:

let
  sftpUser = "sven";
  chrootDir = "/var/www/sven";
in
{
  # Create user and group for SFTP-only access
  users.groups.${sftpUser} = { };
  users.users.${sftpUser} = {
    isNormalUser = true;
    group = sftpUser;
    home = "/"; # Irrelevant for chrooted SFTP
    shell = "${pkgs.shadow}/bin/nologin"; # No interactive shell allowed

    # SSH key authentication (recommended)
    openssh.authorizedKeys.keys = [
      # Add Sven's public key here:
      # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... sven@machine"
    ];

    # Password authentication (for FileZilla/GUI clients)
    # Uncomment ONE of these:
    # initialPassword = "changeme"; # Only for initial setup - change immediately!
    # hashedPassword = "..."; # Use `mkpasswd -m sha-512` to generate
  };

  # OpenSSH SFTP configuration with chroot for this user
  services.openssh = {
    extraConfig = ''
      Match User ${sftpUser}
        ChrootDirectory ${chrootDir}
        ForceCommand internal-sftp -u 0022 -d /html
        X11Forwarding no
        AllowTcpForwarding no
        PermitTTY no
    '';
  };

  # Add nginx to sven's group so it can read uploaded files
  users.users.nginx.extraGroups = [ sftpUser ];

  # Create chroot directory structure
  # ChrootDirectory and all parent directories MUST be root-owned and not group/other writable
  # The user gets a writable subdirectory inside the chroot
  systemd.tmpfiles.rules = [
    # Chroot root: must be root:root with strict permissions
    "d ${chrootDir} 0755 root root - -"

    # User-writable directory inside chroot with setgid for group inheritance
    # SFTP will start here due to -d /html flag
    # 2775: setgid bit ensures new files inherit the sven group
    "d ${chrootDir}/html 02775 ${sftpUser} ${sftpUser} - -"

    # Optional: uploads or temp directory
    # "d ${chrootDir}/uploads 0770 ${sftpUser} ${sftpUser} - -"
  ];
}
