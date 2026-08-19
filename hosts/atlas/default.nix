{ lib, ... }:
{
  imports = [ ./hardware-configuration.nix ./services.nix ]
    ++ lib.optional (builtins.pathExists ../../secrets/secrets.yaml) ./secrets.nix;

  networking.hostName = "atlas";
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "de";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Atlas boots in UEFI mode from the FAT32 EFI system partition mounted at /boot.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Keep routine maintenance predictable on the small internal SSD.
  nix = {
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  services.fstrim.enable = true;
  services.journald.extraConfig = "SystemMaxUse=500M";

  # Use the deployed flake as the source of truth. It runs overnight and only
  # reboots when a kernel, initrd, or kernel module update requires it.
  system.autoUpgrade = {
    enable = true;
    flake = "/etc/nixos#atlas";
    dates = "04:30";
    randomizedDelaySec = "30min";
    allowReboot = true;
  };

  users.users.max = {
    isNormalUser = true;
    description = "Max";
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDrXT9/nMuJk+IiYGHs1SRbDoJkT9QcsItC9sQF3KDfE Max@Malfy"
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Do not change this after the first deployment.
  system.stateVersion = "26.05";
}
