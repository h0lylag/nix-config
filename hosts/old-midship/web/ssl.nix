{ config, ... }:

{
  security.acme = {
    acceptTerms = true;

    # Force Let's Encrypt prod for all certs
    defaults = {
      email = "admin@gravemind.sh";
      server = "https://acme-v02.api.letsencrypt.org/directory";
      group = "nginx";
      dnsProvider = "cloudflare";
      dnsPropagationCheck = true;
      environmentFile = config.sops.secrets.cloudflare.path;
    };

    certs."gravemind.sh" = {
      domain = "gravemind.sh";
      extraDomainNames = [ "*.gravemind.sh" ];
    };

    certs."willamettemachine.com" = {
      domain = "willamettemachine.com";
      extraDomainNames = [ "*.willamettemachine.com" ];
    };

    certs."lambdafleet.org" = {
      domain = "lambdafleet.org";
      extraDomainNames = [ "*.lambdafleet.org" ];
    };

    certs."evepreview.com" = {
      domain = "evepreview.com";
      extraDomainNames = [ "*.evepreview.com" ];
    };

    certs."epm.sh" = {
      domain = "epm.sh";
      extraDomainNames = [ "*.epm.sh" ];
    };

    certs."img.cat" = {
      domain = "img.cat";
      extraDomainNames = [ "*.img.cat" ];
    };
  };
}
