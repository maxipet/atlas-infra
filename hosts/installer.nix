{ modulesPath, pkgs, ... }:
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-graphical-gnome.nix")
  ];

  networking.hostName = "nixos-bootstrap";
  environment.systemPackages = with pkgs; [ git vim tailscale ];
  system.stateVersion = "25.11";
}
