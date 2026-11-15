# Android signing

## Current CI behavior

The app is distributed as a **debug-signed sideload/testing build**. Google Play
is not a target for this release, so you do not need to create or configure a
keystore.

The workflow still supports optional release signing. If all four signing
secrets exist, CI builds a release-signed APK/AAB; if any is missing, it builds
and uploads a debug-signed APK/AAB. The workflow log and the generated
`release-notes.md` state `SIGNING_MODE=release` or `SIGNING_MODE=debug`, and both
are labelled as sideload/testing builds.

| Secret | Purpose |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64 of the `.jks` upload keystore |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias |
| `ANDROID_KEY_PASSWORD` | Key password |

## Generate the keystore in Actions

Run **Actions → generate-keystore → Run workflow**. The workflow:

- generates a 4096-bit RSA key with a 10,000-day validity,
- creates a JKS keystore so the key password can differ from the store password,
- uses two independent random 48-byte passwords,
- verifies the key password with `keytool -certreq`,
- uploads **one** artifact named `android-signing-secrets` for **one day**
  containing `android-signing-secrets.txt` (base64 keystore, alias, store
  password, key password) and `keystore-check.txt`.

The run summary warns that the keystore must be backed up safely. This workflow
is optional and is not needed for the normal sideload build. If you later switch
an installed app from debug to release signing, uninstall the old app once;
data is safe in Supabase.

Download the artifact, store the `.jks` and passwords in a password manager, and
then add the four repository secrets under **Settings → Secrets and variables →
Actions**. Do not commit the keystore or the secrets file.

## Manual keystore creation

```sh
keytool -genkeypair -v -storetype JKS -keystore upload-keystore.jks \
  -keyalg RSA -keysize 4096 -validity 10000 -alias upload
base64 -w0 upload-keystore.jks > upload-keystore.b64
```

Store the `.jks` and passwords in a password manager. Never commit either file.

## Add GitHub secrets

Repository → **Settings** → **Secrets and variables** → **Actions** → **New
repository secret**:

1. `ANDROID_KEYSTORE_BASE64` — contents of `upload-keystore.b64`.
2. `ANDROID_KEYSTORE_PASSWORD`.
3. `ANDROID_KEY_ALIAS` — for example `upload`.
4. `ANDROID_KEY_PASSWORD`.

Re-run **Android build** from the Actions tab. The run summary and release notes
state whether the build was release-signed or debug-signed.
