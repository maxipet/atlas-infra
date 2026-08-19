# Secret setup (never commit plaintext)

This project uses `sops-nix` so secret values are encrypted at rest on Atlas. Do not put passwords, OAuth credentials, API keys, recovery codes, or Tailscale keys in the repository, a committed `.env` file, or chat. Atlas's `secrets.yaml` is deliberately local and ignored by Git.

## First server boot

After NixOS is installed and your SSH key is working, generate an age key *on Atlas*:

```bash
sudo install -d -m 0700 /var/lib/sops-nix
sudo age-keygen -o /var/lib/sops-nix/key.txt
sudo cat /var/lib/sops-nix/key.txt
```

Copy the `age1...` public recipient only. Put the private key in an offline recovery location such as a password manager attachment or encrypted USB backup; never commit it.

Copy `secrets.yaml.example` to a temporary file, fill it locally, and encrypt it as `secrets.yaml`. Keep the encrypted `secrets.yaml` on Atlas only; do not commit it. This repository's NixOS configuration deliberately does not reference it until this step is complete, so the first boot is not blocked by a missing secret file.

After `secrets.yaml` is present, run `sudo nixos-rebuild switch --flake /etc/nixos#atlas` again. The configuration then decrypts the values only into `/run/secrets` and creates root-only Docker environment files for ownCloud and Vaultwarden at service start.

The encrypted local `secrets.yaml` also contains the IONOS DNS API key. After the rebuild, Atlas obtains a Let’s Encrypt certificate for `max-petri.xyz` and `*.max-petri.xyz` through DNS-01 without opening any Fritz!Box ports.

## Secrets that will be needed

- IONOS DNS API key: DNS-01 certificates for `*.max-petri.xyz` (use the `ionos_dns_env` multi-line value exactly as shown in `secrets.yaml.example`)
- IONOS mailbox password for `me@max-petri.xyz`: failure alerts
- Google OAuth client ID and client secret: ownCloud Google Drive mount
- Vaultwarden admin token and backup password

The Google OAuth authorization is completed in the ownCloud UI after deployment. Use the production OAuth app and the redirect URI documented in the repository README.
