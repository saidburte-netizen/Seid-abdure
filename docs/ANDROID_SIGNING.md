# Android signing

## Current CI behavior

If all four signing secrets exist, CI builds a release-signed APK/AAB. If any is
missing, CI still builds and uploads artifacts, but they are **debug-signed** and
must not be published to Google Play.

| Secret | Purpose |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64 of the `.jks` upload keystore |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias |
| `ANDROID_KEY_PASSWORD` | Key password |

## Create the keystore

```sh
keytool -genkeypair -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
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

Re-run **Android build** from the Actions tab. The run summary states whether
the build was release-signed or debug-signed.
