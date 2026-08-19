# Private NixOS home server

This repository builds a graphical bootstrap ISO and configures a private NixOS home server for `max-petri.xyz`.

It includes Docker Compose stacks for Vaultwarden, ownCloud, Dockge, and Jellyfin. Caddy is the only web-facing service; every container port binds only to localhost. Tailscale grants remote access, while a restrictive NixOS firewall allows access from the home LAN.

## Service names

| Service | Address |
| --- | --- |
| Vaultwarden | `https://vault.max-petri.xyz` |
| ownCloud | `https://cloud.max-petri.xyz` |
| Dockge | `https://atlas.max-petri.xyz` |
| Jellyfin | `https://media.max-petri.xyz` |

## DNS and private access

1. Join the host to Tailscale, then obtain its address with `tailscale ip -4`.
2. Point the four public DNS `A` records at that `100.x.y.z` Tailnet address. The address is unreachable from the public Internet; only devices on your Tailnet can route to it.
3. Add DNS overrides for these same records on your router, pointing to the server's fixed LAN address. LAN-only devices will then use the same friendly names.
4. Do **not** forward ports 80 or 443 on your router.

The Caddy setup uses an internal certificate authority to avoid exposing the server for certificate validation. After Caddy starts, distribute and trust this certificate on your client devices:

```text
/var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt
```

For browser-trusted certificates without installing a private root certificate, add DNS-01 ACME later for the provider hosting `max-petri.xyz`.

## Build the ISO from Windows

Install Nix inside WSL2, clone this repository there, then run:

```bash
nix --extra-experimental-features "nix-command flakes" build .#installerIso
```

The ISO is written below `result/iso/`. Flash it with Rufus, then boot the server.

## Deploy the server

1. Copy this repository to `/etc/nixos` on the installed server.
2. Replace `hosts/atlas/hardware-configuration.nix` with the file generated during NixOS installation. The placeholder intentionally stops accidental deployment.
3. In `hosts/atlas/default.nix`, set your actual user name and SSH public key.
4. In `hosts/atlas/services.nix`, set `lanCidr` to your real home-network range. Give the server a fixed DHCP lease in your router.
5. Create secret files from the examples and make them readable only by root:

   ```bash
   cp compose/vaultwarden/.env.example compose/vaultwarden/.env
   cp compose/owncloud/.env.example compose/owncloud/.env
   chmod 600 compose/*/.env
   ```

6. Apply the host configuration:

   ```bash
   sudo nixos-rebuild switch --flake .#atlas
   ```

7. Join the Tailnet and start each stack:

   ```bash
   sudo tailscale up --advertise-tags=tag:home-server
   cd /etc/nixos/compose/vaultwarden && sudo docker compose up -d
   cd /etc/nixos/compose/owncloud && sudo docker compose up -d
   cd /etc/nixos/compose/dockge && sudo docker compose up -d
   cd /etc/nixos/compose/jellyfin && sudo docker compose up -d
   ```

Jellyfin scans host media from `/srv/media`, mounted read-only in the container. Create subfolders such as `/srv/media/Movies`, `/srv/media/TV`, and `/srv/media/Music`. It is intentionally not writable by Jellyfin.

## Tailscale policy starter

Add this to the Tailnet policy, then restrict `autogroup:member` further if you invite other people:

```hujson
{
  "tagOwners": {
    "tag:home-server": ["autogroup:admin"],
  },
  "grants": [
    {
      "src": ["autogroup:member"],
      "dst": ["tag:home-server"],
      "ip": ["tcp:22", "tcp:80", "tcp:443"],
    },
  ],
}
```

## Adding services later

Create a `compose/<service>/compose.yml`, bind its web port to `127.0.0.1`, and add a Caddy virtual host in `hosts/atlas/services.nix`. Store the Compose files in Git; Dockge is a convenient UI, not the source of truth.

Back up `/srv/containers` and application databases to encrypted off-site storage, and test restoration regularly.
