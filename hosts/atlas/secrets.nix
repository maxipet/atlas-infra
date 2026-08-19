{ config, pkgs, ... }:
{
  # This module is loaded only once secrets/secrets.yaml exists and has been
  # encrypted with the Atlas age recipient. Nothing below contains a secret.
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
    secrets = {
      ionos_dns_env = { };
      smtp_password = { };
      owncloud_admin_password = { };
      owncloud_db_password = { };
      mariadb_root_password = { };
      vaultwarden_admin_token = { };
      vaultwarden_backup_password = { };
    };
  };

  # Docker Compose needs values in a root-readable environment file at runtime.
  # sops-nix writes the source values into /run/secrets; no plaintext is stored
  # in Git or in the Nix store.
  systemd.services.homeserver-compose-secrets = {
    description = "Materialize private Compose environment files";
    wantedBy = [ "multi-user.target" ];
    after = [ "sops-nix.service" ];
    requires = [ "sops-nix.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -m 0700 /etc/nixos/compose/owncloud /etc/nixos/compose/vaultwarden

      {
        printf '%s\\n' 'OWNCLOUD_ADMIN_PASSWORD='"$(cat ${config.sops.secrets.owncloud_admin_password.path})"
        printf '%s\\n' 'OWNCLOUD_DB_PASSWORD='"$(cat ${config.sops.secrets.owncloud_db_password.path})"
        printf '%s\\n' 'MARIADB_ROOT_PASSWORD='"$(cat ${config.sops.secrets.mariadb_root_password.path})"
      } > /etc/nixos/compose/owncloud/.env
      chmod 0600 /etc/nixos/compose/owncloud/.env

      printf '%s\\n' 'ADMIN_TOKEN='"$(cat ${config.sops.secrets.vaultwarden_admin_token.path})" \
        > /etc/nixos/compose/vaultwarden/.env
      chmod 0600 /etc/nixos/compose/vaultwarden/.env
    '';
  };
}
