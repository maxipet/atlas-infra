{ pkgs, ... }:
let
  # Change to the CIDR used by your router before deployment.
  lanCidr = "192.168.178.0/24";
  tlsConfig =
    if builtins.pathExists /etc/nixos/secrets/secrets.yaml then
      "tls /var/lib/acme/max-petri.xyz/fullchain.pem /var/lib/acme/max-petri.xyz/key.pem"
    else
      "tls internal";
in
{
  virtualisation.docker.enable = true;

  # Keep the initial Wi-Fi connection managed until Atlas is moved to Ethernet.
  networking.networkmanager.enable = true;

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  services.resolved.enable = true;

  # Lightweight, local-only live system dashboard. Docker's control socket is
  # deliberately not exposed to it.
  systemd.services.glances-web = {
    description = "Glances web monitoring dashboard";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.glances}/bin/glances --webserver --bind 127.0.0.1 --port 61208 --disable-check-update";
      Restart = "on-failure";
      DynamicUser = true;
      StateDirectory = "glances";
    };
  };

  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    extraInputRules = ''
      # Jellyfin's direct HTTP port is for LAN clients such as the Fire TV.
      # It remains blocked from all non-LAN networks; remote access goes via
      # Caddy HTTPS and Tailscale instead.
      # SMB is deliberately available only on the home LAN.
      ip saddr ${lanCidr} tcp dport { 22, 80, 443, 445, 8096 } accept
    '';
  };

  # A conventional authenticated Windows share for adding Jellyfin media.
  # It is private to the LAN; the Samba password is stored by Samba, not Git.
  services.samba = {
    enable = true;
    openFirewall = false;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "Atlas media server";
        "server min protocol" = "SMB2_02";
        "map to guest" = "never";
        "hosts allow" = "127.0.0.1 ${lanCidr}";
      };
      media = {
        path = "/srv/media";
        "browseable" = "yes";
        "read only" = "no";
        "valid users" = "max";
        "force group" = "media";
        "create mask" = "0660";
        "directory mask" = "2770";
        "force create mode" = "0660";
        "force directory mode" = "2770";
      };
    };
  };

  # Containers expose HTTP only on 127.0.0.1. Caddy is their sole HTTPS entry point.
  services.caddy = {
    enable = true;
    virtualHosts = {
      "vault.max-petri.xyz".extraConfig = ''
        ${tlsConfig}
        reverse_proxy 127.0.0.1:8222
      '';
      "cloud.max-petri.xyz".extraConfig = ''
        ${tlsConfig}
        reverse_proxy 127.0.0.1:8081
      '';
      "atlas.max-petri.xyz".extraConfig = ''
        ${tlsConfig}
        reverse_proxy 127.0.0.1:5001
      '';
      "media.max-petri.xyz".extraConfig = ''
        ${tlsConfig}
        reverse_proxy 127.0.0.1:8096
      '';
      "monitor.max-petri.xyz".extraConfig = ''
        ${tlsConfig}
        reverse_proxy 127.0.0.1:61208
      '';
    };
  };

  environment.systemPackages = with pkgs; [ age git glances restic sops vim ];

  systemd.tmpfiles.rules = [
    "d /srv/containers 0750 root root -"
    "d /srv/owncloud 0750 root root -"
    # New media inherits the dedicated media group used by Samba and Jellyfin.
    "d /srv/media 2770 root media -"
    "d /srv/media/Movies 2770 root media -"
    "d /srv/media/TV 2770 root media -"
    "d /srv/media/Music 2770 root media -"
  ];
}
