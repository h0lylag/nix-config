{ config, pkgs, ... }:

{
  security.acme = {
    acceptTerms = true;

    # Force Let's Encrypt prod for all certs
    defaults = {
      email = "admin@gravemind.sh";
      server = "https://acme-v02.api.letsencrypt.org/directory";
    };

    certs."gravemind.sh" = {
      domain = "gravemind.sh";
      extraDomainNames = [ "*.gravemind.sh" ];
      group = "nginx";
      dnsProvider = "cloudflare";
      dnsPropagationCheck = true;
      credentialsFile = /run/secrets/cloudflare;
    };

    certs."willamettemachine.com" = {
      domain = "willamettemachine.com";
      extraDomainNames = [ "*.willamettemachine.com" ];
      group = "nginx";
      dnsProvider = "cloudflare";
      dnsPropagationCheck = true;
      credentialsFile = /run/secrets/cloudflare;
    };

    certs."lambdafleet.org" = {
      domain = "lambdafleet.org";
      extraDomainNames = [ "*.lambdafleet.org" ];
      group = "nginx";
      dnsProvider = "cloudflare";
      dnsPropagationCheck = true;
      credentialsFile = /run/secrets/cloudflare;
    };

    certs."multiboxxed.space" = {
      domain = "multiboxxed.space";
      extraDomainNames = [ "auth.multiboxxed.space" ];
      group = "nginx";
      dnsProvider = "cloudflare";
      dnsPropagationCheck = true;
      credentialsFile = /run/secrets/cloudflare;
    };
  };
}
