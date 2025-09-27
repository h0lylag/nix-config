{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.mail2discord;
in
{
  options.services.mail2discord = {
    enable = lib.mkEnableOption "Intercept local email via sendmail and forward to Discord";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../pkgs/mail2discord/default.nix { };
      description = "mail2discord package providing the CLI and sendmail shim.";
    };

    # Name of the secret key in sops (in defaultSopsFile) to write to /run/secrets/mail2discord-webhook
    secretName = lib.mkOption {
      type = lib.types.str;
      default = "mail2discord-webhook";
      description = "Key in sops file whose value is the Discord webhook URL.";
    };

    # Optional: override path where sendmail shim is exposed
    sendmailPath = lib.mkOption {
      type = lib.types.str;
      default = "/usr/sbin/sendmail";
      description = "Location for the system sendmail symlink.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure the webhook secret exists at /run/secrets/mail2discord-webhook
    # This uses sops.defaultSopsFile from common.nix unless overridden elsewhere.
    sops.secrets."${cfg.secretName}" = lib.mkDefault { };

    environment.systemPackages = [ cfg.package ];

    # Provide an alternatives-managed sendmail that points at our wrapper.
    # We'll install a wrapper in /run/current-system/sw/bin/sendmail-mail2discord via the package
    # and expose it as the system's sendmail through /etc/alternatives and /usr/sbin/sendmail.
    environment.etc."alternatives/sendmail".source = "${cfg.package}/bin/sendmail-mail2discord";

    # Ensure directory exists and create /usr/sbin/sendmail -> /etc/alternatives/sendmail
    systemd.tmpfiles.rules = [
      "L+ ${cfg.sendmailPath} - - - - /etc/alternatives/sendmail"
    ];

    # Document the dependency on sops-nix activation
    assertions = [
      {
        assertion = config ? sops;
        message = "services.mail2discord requires sops-nix module to be imported.";
      }
    ];
  };
}
