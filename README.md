# Private NixOS home server

This repository builds a graphical bootstrap ISO and configures a private NixOS home server for `max-petri.xyz`.

It includes Docker Compose stacks for Vaultwarden, ownCloud Classic, Dockge, and Jellyfin. Caddy is the only web-facing service; every container port binds only to localhost. Tailscale grants remote access, while a restrictive NixOS firewall allows access from the home LAN.

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

The final deployment will use browser-trusted certificates through IONOS DNS-01 validation. DNS validation does not require ports 80 or 443 to be publicly reachable. The IONOS API key is an encrypted secret; see `secrets/README.md`.

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
4. `hosts/atlas/services.nix` already uses your Fritz!Box LAN range, `192.168.178.0/24`. Give the server a fixed DHCP lease in your router.
5. Complete [the secret setup](secrets/README.md) before creating any application `.env` files. They must be generated locally from encrypted secrets, owned by root, and never committed.

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

Jellyfin scans `/srv/media/Movies`, `/srv/media/TV`, and `/srv/media/Music`, mounted read-only in the container. The media is deliberately disposable and is excluded from backup. ownCloud's small local state is at `/srv/owncloud`; set your ownCloud user's local quota to 1 GB and mount Google Drive privately through the ownCloud admin UI.

The preconfigured ownCloud administrator is `max`. Follow [the Google Drive setup guide](compose/owncloud/GOOGLE_DRIVE_SETUP.md) after the first login to mount the entire personal Google Drive privately.

Use [INSTALL.md](INSTALL.md) for the agreed 50 GB system / remaining `/srv` disk layout.

## Network model

- Tailscale is enabled on the host and the `tailscale0` interface is trusted only after Tailnet policy authorizes a connection.
- The LAN firewall permits SSH and HTTPS only from `192.168.178.0/24`.
- Docker services bind their ports to `127.0.0.1`; only Caddy can reach them from the LAN or Tailnet.
- Do not configure router port forwarding. This is especially important because many home connections have publicly routable IPv6.
- Use a Fritz!Box DNS rebind/local-DNS override for the service names to resolve to Atlas's LAN address at home. Tailnet clients can resolve them to its stable Tailscale address.

## Secrets, certificates, and alerts

Plaintext secrets are not part of this repository. Follow [the secret setup instructions](secrets/README.md) after installation. The intended alert path is failure-only email from `me@max-petri.xyz` to the same address through IONOS SMTP. You enter the mailbox password locally as an encrypted secret. Until that secret has been set up, the system deliberately does not try to send mail.

For ownCloud Google Drive integration, use a personal Google OAuth application in **Production** mode and configure this redirect URI:

```text
https://cloud.max-petri.xyz/index.php/settings/admin?sectionid=storage
```

Testing-mode Drive OAuth refresh tokens expire after seven days.

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

The only automated backup planned for this first stage is a small encrypted Vaultwarden backup to Google Drive. Jellyfin media and the Google Drive-mounted ownCloud files are intentionally excluded.
