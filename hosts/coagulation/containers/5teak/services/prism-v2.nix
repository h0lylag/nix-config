# Prism v2 at prism.gravemind.sh. TLS ends on midship, which proxies here
# over Tailscale; v1 is beside it as prism-v1 (prism-django.nix).
#
# The database must exist before the first switch, made by hand with the
# builtin C.UTF-8 locale that Prism checks: this cluster's default is
# en_US.UTF-8, which `ensureDatabases` would use.
#
#   CREATE ROLE prism LOGIN;
#   CREATE DATABASE prism OWNER prism TEMPLATE template0 ENCODING UTF8
#     LOCALE 'C.UTF-8' LOCALE_PROVIDER builtin BUILTIN_LOCALE 'C.UTF-8';
{ config, ... }:

{
  sops.secrets.prism-v2-env = {
    sopsFile = ../../../../../secrets/prism-v2.env;
    format = "dotenv";
    owner = "prism";
    group = "prism";
    restartUnits = [
      "prism-web.service"
      "prism-processor.service"
      "prism-resolver.service"
      "prism-sender.service"
      "prism-killfeed.service"
      "prism-killdays.service"
    ];
  };

  services.prism = {
    enable = true;
    hosts = [ "prism.gravemind.sh" ];
    userAgent = "Prism/2";
    environmentFile = config.sops.secrets.prism-v2-env.path;
    # v1's Uvicorn has 8000.
    web.port = 8001;
    nginx = {
      enable = true;
      # midship's Tailscale address: the TLS edge for prism.gravemind.sh.
      trustedProxies = [ "100.83.47.31" ];
    };
  };
}
