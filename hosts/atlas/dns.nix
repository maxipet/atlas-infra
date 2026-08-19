{ config, ... }:
{
  # This file is imported only after the encrypted IONOS secret exists.
  sops = {
    age.keyFile = "/var/lib/sops-nix/key.txt";
    secrets.ionos_dns_env.sopsFile = ../../secrets/ionos.yaml;
  };

  # DNS-01 proves domain ownership without exposing any port on the Fritz!Box.
  security.acme = {
    acceptTerms = true;
    certs."max-petri.xyz" = {
      email = "me@max-petri.xyz";
      extraDomainNames = [ "*.max-petri.xyz" ];
      dnsProvider = "ionos";
      environmentFile = config.sops.secrets.ionos_dns_env.path;
      group = "caddy";
      reloadServices = [ "caddy.service" ];
    };
  };
}
