# Atlas installation runbook

This is the one-time installation plan for the 256 GB SSD. It does not use disk encryption, as agreed.

## Disk layout

| Mount point | Size | Purpose |
| --- | ---: | --- |
| `/boot` | 1 GB | UEFI boot partition (FAT32) |
| `/` | 50 GB | NixOS, package store, logs, and rollback generations |
| `/srv` | remaining space | ownCloud state, containers, and disposable Jellyfin media |

Use GPT and ext4 for `/` and `/srv`. The installer will show the actual disk name; verify it carefully before formatting. Do not use a disk name from another machine or guide.

After mounting the filesystems under `/mnt`, run `nixos-generate-config --root /mnt`, copy the generated `hardware-configuration.nix` into this repository, and use the repository configuration for installation.

## First boot order

1. Set a Fritz!Box DHCP reservation for Atlas.
2. Log in as `max` using the already-configured SSH public key.
3. Create Atlas's local age key and encrypted secrets, following `secrets/README.md`.
4. Configure IONOS DNS-01 certificates before publishing the service DNS records.
5. Start the Compose stacks and complete the ownCloud Google Drive authorization.

Do not expose ports on the Fritz!Box. Tailnet access is through Tailscale only.
