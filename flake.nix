{
  description = "Max Petri's private NixOS home server";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = { self, nixpkgs }: {
    nixosConfigurations.atlas = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./hosts/atlas/default.nix ];
    };

    nixosConfigurations.installer = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./hosts/installer.nix ];
    };

    packages.x86_64-linux.installerIso =
      self.nixosConfigurations.installer.config.system.build.isoImage;
  };
}
