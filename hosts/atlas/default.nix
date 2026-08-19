{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./services.nix
  ];

  networking.hostName = "atlas";
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

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
      # Add your key before deployment, for example:
      # "ssh-ed25519 AAAA... max@laptop"
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
