{ config, pkgs, ... }:
{
  # This module is loaded only once secrets/secrets.yaml exists and has been
  # encrypted with the Atlas age recipient. Nothing below contains a secret.
  sops = {
    defaultSopsFile = /etc/nixos/secrets/secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
    secrets = {
      ionos_dns_env = { };
      smtp_password = { };
      owncloud_admin_password = { };
      owncloud_db_password = { };
      mariadb_root_password = { };
      vaultwarden_admin_token = { };
      vaultwarden_backup_password = { };
      n8n_db_password = { };
      n8n_encryption_key = { };
      n8n_runners_auth_token = { };
    };
  };

  # DNS-01 proves domain ownership without exposing any Fritz!Box ports.
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

  # Docker Compose needs values in a root-readable environment file at runtime.
  # sops-nix writes the source values into /run/secrets; no plaintext is stored
  # in Git or in the Nix store.
  systemd.services.homeserver-compose-secrets = {
    description = "Materialize private Compose environment files";
    wantedBy = [ "multi-user.target" ];
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # These are tracked source directories and must remain traversable by the
      # non-root Git operator. Only the generated .env files are private.
      install -d -m 0755 \
        /etc/nixos/compose/owncloud \
        /etc/nixos/compose/vaultwarden \
        /etc/nixos/compose/n8n

      {
        printf '%s\n' 'OWNCLOUD_ADMIN_PASSWORD='"$(cat ${config.sops.secrets.owncloud_admin_password.path})"
        printf '%s\n' 'OWNCLOUD_DB_PASSWORD='"$(cat ${config.sops.secrets.owncloud_db_password.path})"
        printf '%s\n' 'MARIADB_ROOT_PASSWORD='"$(cat ${config.sops.secrets.mariadb_root_password.path})"
      } > /etc/nixos/compose/owncloud/.env
      chmod 0600 /etc/nixos/compose/owncloud/.env

      printf '%s\n' 'ADMIN_TOKEN='"$(cat ${config.sops.secrets.vaultwarden_admin_token.path})" \
        > /etc/nixos/compose/vaultwarden/.env
      chmod 0600 /etc/nixos/compose/vaultwarden/.env

      {
        printf '%s\n' 'N8N_DB_PASSWORD='"$(cat ${config.sops.secrets.n8n_db_password.path})"
        printf '%s\n' 'N8N_ENCRYPTION_KEY='"$(cat ${config.sops.secrets.n8n_encryption_key.path})"
        printf '%s\n' 'N8N_RUNNERS_AUTH_TOKEN='"$(cat ${config.sops.secrets.n8n_runners_auth_token.path})"
      } > /etc/nixos/compose/n8n/.env
      chmod 0600 /etc/nixos/compose/n8n/.env

    '';
  };
}
