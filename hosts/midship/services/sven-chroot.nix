{
  config,
  pkgs,
  lib,
  ...
}:

let
  noShell = "/run/current-system/sw/bin/nologin";
in
{
  users.groups.sftponly = { };

  users.users.sven = {
    isNormalUser = true;
    home = "/srv/www/sven"; # chroot base = home
    createHome = false; # we’ll create it via tmpfiles
    shell = noShell; # no SSH shell
    extraGroups = [
      "sftponly"
      "nginx"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWU3a+HOcu4woQiuMoCSxrW8g916Z9P05DW8o7cGysH chris@relic"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /srv/www 0755 root root -"
    "d /srv/www/sven 0755 root root -"
    "d /srv/www/sven/html 2775 sven nginx -"
  ];

  services.openssh = {
    enable = true;
    extraConfig = ''
      Subsystem sftp internal-sftp
      Match Group sftponly
        ChrootDirectory /srv/www/%u
        ForceCommand internal-sftp -d /html
        AllowTcpForwarding no
    '';
  };

  #services.nginx.virtualHosts."sven.example.com" = {
  #  root = "/srv/www/sven/html";
  #  # add your usual index, TLS, etc.
  #};
}
