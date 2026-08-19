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
      ip saddr ${lanCidr} tcp dport { 22, 80, 443, 8096 } accept
    '';
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
    # The directory remains inaccessible to non-root host users. The two
    # containers receive group 0 explicitly so OwnCloud can write uploads and
    # Jellyfin can read them.
    "d /srv/media 0775 root root -"
    "d /srv/media/Movies 0755 root root -"
    "d /srv/media/TV 0755 root root -"
    "d /srv/media/Music 0755 root root -"
  ];
}
