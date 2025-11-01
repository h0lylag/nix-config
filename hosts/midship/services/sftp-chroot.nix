# SFTP-only chrooted user configuration for midship
# Uses the sftp-chroot module from modules/sftp-chroot.nix
{ ... }:

{
  services.sftpChroot = {
    enable = true;
    baseDir = "/srv/www";
    group = "sftpusers";
    umask = "0002"; # Files 664, dirs 775 (group writable)
    addNginxToGroup = false; # midship doesn't have nginx yet
    passwordAuth = true; # Allow password authentication
    requireAuth = false; # Can set password later with: sudo passwd sven

    users.sven = {
      # Password set via: sudo passwd sven
      # Or pre-hash with: mkpasswd -m sha-512
      # passwordHash = "$6$...";

      # Optional: SSH key authentication
      # authorizedKeys = [
      #   "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... sven@machine"
      # ];
    };
  };
}
