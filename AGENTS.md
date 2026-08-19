# Repository guidance for agents

## Documentation is part of the change

Keep `README.md` accurate whenever a change affects Atlas's architecture, service inventory, network exposure, storage locations, secret flow, maintenance commands, backup or recovery posture, deployment procedure, or operational risks. Update the relevant section in the same change; do not defer it to a follow-up.

If a change makes the README's architecture diagram or service table inaccurate, update both. Never add real secrets, private keys, tokens, `.env` values, or personally sensitive operational data to documentation or committed files.

For one-time installation details, maintain `INSTALL.md`; for secrets enrollment and handling, maintain `secrets/README.md`. Keep the three documents consistent and link between them rather than duplicating procedures that are likely to drift.
