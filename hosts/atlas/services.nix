{ pkgs, ... }:
let
  # Change to the CIDR used by your router before deployment.
  lanCidr = "192.168.178.0/24";
in
{
  virtualisation.docker.enable = true;

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

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
        tls internal
        reverse_proxy 127.0.0.1:8222
      '';
      "cloud.max-petri.xyz".extraConfig = ''
        tls internal
        reverse_proxy 127.0.0.1:8081
      '';
      "dockge.max-petri.xyz".extraConfig = ''
        tls internal
        reverse_proxy 127.0.0.1:5001
      '';
      "media.max-petri.xyz".extraConfig = ''
        tls internal
        reverse_proxy 127.0.0.1:8096
      '';
    };
  };

  environment.systemPackages = with pkgs; [ git vim restic ];

  systemd.tmpfiles.rules = [
    "d /srv/containers 0750 root root -"
    "d /srv/media 0755 root root -"
  ];
}
