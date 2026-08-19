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

  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    extraInputRules = ''
      ip saddr ${lanCidr} tcp dport { 22, 80, 443 } accept
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
        reverse_proxy 127.0.0.1:8090
      '';
    };
  };

  environment.systemPackages = with pkgs; [ age git restic sops vim ];

  systemd.tmpfiles.rules = [
    "d /srv/containers 0750 root root -"
    "d /srv/owncloud 0750 root root -"
    "d /srv/media 0755 root root -"
    "d /srv/media/Movies 0755 root root -"
    "d /srv/media/TV 0755 root root -"
    "d /srv/media/Music 0755 root root -"
  ];
}
