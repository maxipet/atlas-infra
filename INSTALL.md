# Atlas installation runbook

This is the one-time installation plan for the 256 GB SSD. It does not use disk encryption, as agreed.

## Disk layout

| Mount point | Size | Purpose |
| --- | ---: | --- |
| `/boot` | 1 GB | UEFI boot partition (FAT32) |
| `/` | 50 GB | NixOS, package store, logs, and rollback generations |
| `/srv` | remaining space | ownCloud state, containers, and disposable Jellyfin media |

Use GPT and ext4 for `/` and `/srv`. The installer will show the actual disk name; verify it carefully before formatting. Do not use a disk name from another machine or guide.

After mounting the filesystems under `/mnt`, run `nixos-generate-config --root /mnt` and install the generated base system. It is a temporary, headless system used only to get onto the network.

## Deploy Atlas after the first boot

Connect the server to the network, then log in locally as `root`. The following keeps the generated hardware file on the server and checks out Atlas into `/etc/nixos`, which is the location used for future declarative updates:

```bash
nix-shell -p git
cd /etc/nixos
git init
git remote add origin https://github.com/maxipet/atlas-infra.git
git fetch origin
git switch --track origin/main
cp /etc/nixos/hardware-configuration.nix hosts/atlas/hardware-configuration.nix
NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --impure --flake /etc/nixos#atlas
```

The first Atlas rebuild creates the `max` account and enables key-only SSH. Test `ssh max@<server-ip>` from the Windows PC before unplugging the monitor. Atlas keeps NetworkManager enabled while it is on Wi-Fi; simply connect Ethernet later and it will obtain an address from the Fritz!Box automatically.

## First boot order

1. Set a Fritz!Box DHCP reservation for Atlas.
2. Log in as `max` using the already-configured SSH public key.
3. Create Atlas's local age key and encrypted secrets, following `secrets/README.md`.
4. Configure IONOS DNS-01 certificates before publishing the service DNS records.
5. Start the Compose stacks and complete the ownCloud Google Drive authorization.

Do not expose ports on the Fritz!Box. Tailnet access is through Tailscale only.
