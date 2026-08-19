# Atlas home server

Atlas is a private NixOS home server for `max-petri.xyz`. This repository is the declarative source of truth for the operating system, network edge, and Docker Compose definitions. It also produces a graphical NixOS bootstrap ISO.

Use this document for routine operation and when changing the system. Use [INSTALL.md](INSTALL.md) only for the initial machine installation, and [secrets/README.md](secrets/README.md) for the secret-enrollment procedure.

## Architecture

```text
Tailnet clients ──┐
                  ├── HTTPS ──> Caddy on Atlas ──> localhost-only containers
LAN clients ──────┘               │                  ├─ Vaultwarden :8222
                                  │                  ├─ ownCloud    :8081
                                  │                  ├─ Dockge      :5001
                                  │                  └─ Jellyfin    :8096
                                  │
                                  └── ACME DNS-01 certificates (IONOS)

NixOS configuration (/etc/nixos) ──> host services, firewall, Caddy, Docker,
                                      Tailscale, sops-nix, upgrades and cleanup
```

The system has one host, `atlas`, running NixOS 26.05 on x86_64 Linux. The disk layout is a 50 GB root filesystem and a separate `/srv` filesystem using remaining space. `/srv` holds application data, container state, and media; see [INSTALL.md](INSTALL.md).

### Request and trust boundaries

| Layer | Responsibility | Exposure |
| --- | --- | --- |
| Fritz!Box / DNS | LAN DHCP reservation and local DNS override | No port forwarding |
| Tailscale | Private remote connectivity | Tailnet policy controls access |
| NixOS firewall | Permits SSH/HTTP/HTTPS from `192.168.178.0/24`; trusts `tailscale0` | Public Internet is blocked |
| Caddy | TLS termination and reverse proxy | Only service reachable on LAN/Tailnet |
| Docker Compose | Runs application containers | Published ports bind to `127.0.0.1` only |
| sops-nix | Decrypts server-local encrypted secrets into `/run/secrets` | Plaintext is not committed or stored in the Nix store |

The firewall and the Compose port bindings are deliberate defense-in-depth. Do not add router port forwarding, including for IPv6.

## Services

| Service | Public URL | Upstream | Persistent data | Notes |
| --- | --- | ---: | --- | --- |
| Vaultwarden | `https://vault.max-petri.xyz` | `127.0.0.1:8222` | `/srv/containers/vaultwarden` | Signups disabled; invitations enabled |
| ownCloud | `https://cloud.max-petri.xyz` | `127.0.0.1:8081` | `/srv/owncloud/files`, MariaDB and Redis under `/srv/containers/owncloud` | Admin username: `max` |
| Dockge | `https://atlas.max-petri.xyz` | `127.0.0.1:5001` | `/srv/containers/dockge` | Convenience UI; Git remains source of truth |
| Jellyfin | `https://media.max-petri.xyz` | `127.0.0.1:8096` | config/cache in `/srv/containers/jellyfin`; reads `/srv/media` | Media is mounted read-only and is disposable |

Compose definitions are in `compose/<service>/compose.yml`. Docker image tags currently follow upstream `latest` except MariaDB and Redis, which are pinned to major image tags. Treat image changes as production changes: review release notes and verify each service after recreating it.

## Repository map

| Path | Purpose |
| --- | --- |
| `flake.nix` | Nix inputs and outputs for the `atlas` host and bootstrap ISO |
| `hosts/atlas/default.nix` | Base host settings, users, SSH, Nix cleanup, automatic upgrades |
| `hosts/atlas/services.nix` | Docker, Tailscale, firewall, Caddy routes, data directories |
| `hosts/atlas/secrets.nix` | sops-nix integration, ACME DNS-01, Compose secret materialization |
| `hosts/atlas/hardware-configuration.nix` | Machine-specific generated hardware configuration |
| `compose/` | Versioned Compose stack definitions |
| `secrets/` | Secret schema and enrollment documentation; actual `secrets.yaml` is local and ignored |
| `INSTALL.md` | One-time bootstrap and storage layout runbook |

## Routine operations

Run these commands on Atlas. The deployed checkout is `/etc/nixos`.

### Check health

```bash
sudo systemctl --failed
sudo systemctl status caddy tailscaled docker
sudo docker compose -f /etc/nixos/compose/vaultwarden/compose.yml ps
sudo docker compose -f /etc/nixos/compose/owncloud/compose.yml ps
sudo docker compose -f /etc/nixos/compose/dockge/compose.yml ps
sudo docker compose -f /etc/nixos/compose/jellyfin/compose.yml ps
df -h / /srv
sudo journalctl -p warning..alert --since "24 hours ago"
```

Verify each service URL from both the LAN and Tailnet after network, Caddy, certificate, or firewall changes.

### Apply repository changes

```bash
cd /etc/nixos
git pull --ff-only
sudo nixos-rebuild switch --impure --flake /etc/nixos#atlas
```

`--impure` is required because the encrypted secret file at `/etc/nixos/secrets/secrets.yaml` is intentionally local and Git-ignored. Rebuild before restarting a Compose stack when a configuration or secret-materialization change is involved.

To apply an application-only Compose change:

```bash
cd /etc/nixos/compose/<service>
sudo docker compose up -d
sudo docker compose ps
```

The host checks for declarative updates nightly at 04:30 with up to 30 minutes random delay. It keeps Nix generations for 14 days, optimizes the store automatically, and reboots only when required by a kernel, initrd, or kernel-module update.

### Inspect logs

```bash
sudo journalctl -u caddy -u tailscaled -u docker --since "1 hour ago"
sudo docker compose -f /etc/nixos/compose/<service>/compose.yml logs --tail=100
sudo journalctl -u homeserver-compose-secrets --no-pager
```

Never paste `.env` contents, `/run/secrets/*`, or the age private key into a ticket, terminal recording, or chat.

## Change procedures

### Add or alter a web service

1. Add or update `compose/<service>/compose.yml`; publish the HTTP port only as `127.0.0.1:<host-port>:<container-port>`.
2. Add the matching Caddy virtual host in `hosts/atlas/services.nix`.
3. If values are secret, add the key to `secrets/secrets.yaml.example`, declare it in `hosts/atlas/secrets.nix`, and materialize it only at runtime. Do not commit a `.env` file.
4. Update the service table and architecture in this README.
5. Run `sudo nixos-rebuild switch --impure --flake /etc/nixos#atlas`, start or recreate the stack, then test the URL from LAN and Tailnet.

### Change networking or TLS

Keep service DNS records pointed to Atlas's Tailscale address for remote clients and configure router DNS overrides to Atlas's fixed LAN address for LAN clients. Certificates use IONOS DNS-01, so HTTPS does not require Internet-reachable ports 80 or 443.

Before changing firewall rules, Tailscale ACLs, DNS, or Caddy routes, preserve an active SSH session and test in a second session. The intended Tailnet tag is `tag:home-server`; an example policy is retained below.

### Change secrets

Follow [secrets/README.md](secrets/README.md). After changing encrypted values, copy the encrypted file to the server-local `/etc/nixos/secrets/secrets.yaml` and rebuild with `--impure`. The `homeserver-compose-secrets` oneshot writes root-only `.env` files for ownCloud and Vaultwarden. Restart the affected Compose stack to consume a changed value.

## Backup, recovery, and capacity

No automated backup job is currently configured in this repository. The intended first backup is a small encrypted Vaultwarden backup to Google Drive, but this remains future work. Until an implementation is committed and tested, treat Vaultwarden and ownCloud data as unprotected.

Include in any backup plan:

- `/srv/containers/vaultwarden`
- `/srv/owncloud/files` and `/srv/containers/owncloud` (MariaDB must be backed up consistently)
- `/srv/containers/dockge` and `/srv/containers/jellyfin/config`
- `/etc/nixos`, excluding plaintext secrets but including access to the encrypted `secrets.yaml` and a separately secured age private-key recovery copy

Jellyfin media in `/srv/media` and Google Drive data mounted through ownCloud are deliberately excluded from the proposed backup scope. Check `/srv` capacity weekly and before large media imports; root has only 50 GB and Nix retains 14 days of generations.

For a failed declarative deployment, select an earlier NixOS generation from the boot menu or run `sudo nixos-rebuild switch --rollback`. For a failed container update, restore the previous versioned Compose definition, run `sudo docker compose up -d`, and inspect its logs.

## Initial deployment essentials

1. Build the installer ISO from WSL2 with `nix --extra-experimental-features "nix-command flakes" build .#installerIso`.
2. Install using [INSTALL.md](INSTALL.md), then replace the placeholder hardware file with the installer-generated configuration.
3. Configure the `max` SSH key, router DHCP reservation, Tailscale, and encrypted secrets.
4. Apply the host configuration and start the Compose stacks.
5. Configure the ownCloud Google Drive mount using [compose/owncloud/GOOGLE_DRIVE_SETUP.md](compose/owncloud/GOOGLE_DRIVE_SETUP.md). Use a Production OAuth application: testing-mode refresh tokens expire after seven days.

## Tailscale policy starter

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

Restrict `autogroup:member` if additional Tailnet users are invited.
