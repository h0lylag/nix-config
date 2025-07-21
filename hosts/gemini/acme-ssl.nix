{ config, pkgs, ... }:

{
  # SSL Certificates (ACME with Cloudflare DNS)
  security.acme = {
    acceptTerms = true;
    defaults.email = "admin@gravemind.sh";

    certs."gravemind.sh" = {
      domain = "gravemind.sh";
      extraDomainNames = [ "*.gravemind.sh" ];
      group = "nginx";
      dnsProvider = "cloudflare";
      dnsPropagationCheck = true;
      credentialsFile = /etc/nix-secrets/cloudflare;
    };

    certs."lambdafleet.org" = {
      domain = "lambdafleet.org";
      extraDomainNames = [ "*.lambdafleet.org" ];
      group = "nginx";
      dnsProvider = "cloudflare";
      dnsPropagationCheck = true;
      credentialsFile = /etc/nix-secrets/cloudflare;
    };

    certs."multiboxxed.space" = {
      domain = "multiboxxed.space";
      extraDomainNames = [ "auth.multiboxxed.space" ];
      group = "nginx";
      dnsProvider = "cloudflare";
      dnsPropagationCheck = true;
      credentialsFile = /etc/nix-secrets/cloudflare;
    };

  };
}
