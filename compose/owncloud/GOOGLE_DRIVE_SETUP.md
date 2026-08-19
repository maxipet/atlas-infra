# Google Drive setup for ownCloud

The ownCloud administrator is fixed to `max`. Its password belongs in the encrypted deployment secret, never in Git.

After the server is available at `https://cloud.max-petri.xyz` with a trusted public certificate:

1. Sign in as `max`.
2. Go to **Settings → Apps** and enable **External storage support**.
3. Go to **Settings → Admin → Storage** and enable External Storage.
4. Add a storage of type **Google Drive**.
5. Give it the mount point name `Google Drive` and leave the subfolder empty to mount the entire Drive.
6. Restrict **Available for** to `max`; do not enable sharing.
7. Enter the OAuth client ID and client secret stored in your password manager, then select **Grant access** and sign in with the personal Google account.
8. In **Settings → Users**, set `max`'s local ownCloud quota to `1 GB`. The Google Drive mount is external storage and is not counted against the local quota by default.

The required OAuth redirect URI is:

```text
https://cloud.max-petri.xyz/index.php/settings/admin?sectionid=storage
```

Keep the OAuth consent screen in Production mode; Google Drive access tokens issued while the app is in Testing mode expire after seven days.
