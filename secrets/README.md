# Secret setup (never commit plaintext)

This project uses `sops-nix` so secret values can be encrypted in Git. Do not put passwords, OAuth credentials, API keys, recovery codes, or Tailscale keys in the repository, a `.env` file that is committed, or chat.

## First server boot

After NixOS is installed and your SSH key is working, generate an age key *on Atlas*:

```bash
sudo install -d -m 0700 /var/lib/sops-nix
sudo age-keygen -o /var/lib/sops-nix/key.txt
sudo cat /var/lib/sops-nix/key.txt
```

Copy the `age1...` public recipient only. Put the private key in an offline recovery location such as a password manager attachment or encrypted USB backup; never commit it.

Create `.sops.yaml` from `.sops.yaml.example`, replace the recipient, then create encrypted `secrets.yaml`. Only the encrypted `secrets.yaml` should be committed.

## Secrets that will be needed

- IONOS DNS API key: DNS-01 certificates for `*.max-petri.xyz`
- IONOS mailbox password for `me@max-petri.xyz`: failure alerts
- Google OAuth client ID and client secret: ownCloud Google Drive mount
- Vaultwarden admin token and backup password

The Google OAuth authorization is completed in the ownCloud UI after deployment. Use the production OAuth app and the redirect URI documented in the repository README.
