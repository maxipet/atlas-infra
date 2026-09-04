# n8n setup and operating notes

The n8n editor is available at `https://n8n.max-petri.xyz` from the home LAN and
Tailnet. Caddy terminates TLS and forwards to n8n on `127.0.0.1:5678`; PostgreSQL
and the external task runner have no host ports.

## First start

Complete the repository-wide secret enrollment first. Then deploy the host
configuration and start the stack:

```bash
sudo nixos-rebuild switch --impure --flake /etc/nixos#atlas
cd /etc/nixos/compose/n8n
sudo docker compose pull
sudo docker compose up -d
sudo docker compose ps
sudo docker compose logs --tail=100 n8n task-runner postgres
curl -fsS https://n8n.max-petri.xyz/healthz
```

Open the editor and create the owner account. Use a long, unique password and
enable two-factor authentication under personal settings. Do not put the owner
password or application credentials into this repository.

The image versions for n8n and its runner must always match. Review n8n release
notes, back up the database, update both tags together, pull both images, and
then recreate the stack.

## Personal and Formula Student separation

This is initially one instance, so the separation is organizational rather
than a security boundary. Apply these conventions from the first workflow:

- Give every team workflow the `formula-student` tag and prefix its name with
  `FS |`. Do not apply that tag or prefix to personal workflows.
- Create a separate n8n credential named `Formula Student - Notion` using a
  team-owned Notion internal integration. Grant it access only to the Formula
  Student pages/databases it needs. Never reuse a personal Notion credential.
- Keep team webhook paths, email senders, API accounts, and any other
  credentials team-owned and separate, even if a personal account could work.
- Avoid calling untagged personal sub-workflows from team workflows. If shared
  logic is unavoidable, duplicate it before the instance split.

The Atlas firewall has no public ingress. Scheduled workflows and outgoing API
calls work normally, but Internet services cannot call n8n webhooks. Do not add
router port forwarding to solve this. A future public webhook requirement needs
an explicit, authenticated ingress design and a security review.

## Move Formula Student to its own instance later

1. Disable the tagged Formula Student workflows on Atlas and wait for running
   executions to finish.
2. Export every workflow tagged `formula-student` from the editor. Treat the
   JSON files as sensitive because workflow parameters can contain data even
   though stored credential secrets aren't exported.
3. Deploy the team instance with its own database, encryption key, hostname,
   owner account, backups, and team-controlled lifecycle.
4. Import the workflows, recreate each credential with team-owned secrets, and
   select the recreated credentials in every node.
5. Update webhook and OAuth callback URLs, test manually, then activate the new
   workflows one at a time.
6. Confirm at least one successful production run per workflow before deleting
   the disabled copies and unused team credentials from Atlas.

Do not copy Atlas's PostgreSQL data directory or reuse its encryption key for
the split. Export/import produces a clean ownership boundary and avoids moving
personal credentials or execution history to the team instance.

## Data and recovery

PostgreSQL data is stored under `/srv/containers/n8n/postgres`; n8n's settings
and filesystem binary data are under `/srv/containers/n8n/data`. Execution data
is pruned after 14 days or 10,000 executions, whichever limit is reached first.

A usable recovery set needs a consistent PostgreSQL dump, the n8n data
directory, the encrypted `secrets.yaml`, and an independently secured copy of
the Atlas age private key. The `n8n_encryption_key` must survive recovery or
stored n8n credentials cannot be decrypted.
