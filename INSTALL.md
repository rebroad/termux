# Installing the Termux applications

This repository collects the Termux application repositories used for the
rebroad build. The application source remains in the individual submodules;
this document describes installing APKs to an Android device over USB.

## Prepare the repositories

```sh
git clone https://github.com/rebroad/termux.git ~/src/termux
cd ~/src/termux
git submodule update --init --recursive
```

Build the APKs in the relevant submodule according to its own instructions.
Do not commit generated APKs or private signing keys to this repository.

## USB debugging enabled

On the phone, enable **Developer options → USB debugging**, connect the USB
cable, and approve the computer-authorisation prompt. Verify the device:

```sh
adb devices
```

Then install one or more APKs with:

```sh
./scripts/install-termux.sh path/to/termux-app.apk
```

For multiple packages, pass each APK as an argument. To select a particular
device, set `ANDROID_SERIAL` or use `--serial`:

```sh
./scripts/install-termux.sh --serial SERIAL path/to/termux-app.apk
```

The script uses `adb install -r`, preserving the application data. It checks
that the selected device is present before installing.

## USB debugging disabled

ADB cannot install an APK when USB debugging is disabled. This is an Android
security boundary; a USB cable alone does not provide an installation API.

You can still use the helper to copy the APK to a directory where the phone's
storage is mounted (for example, an MTP-mounted `Download` directory):

```sh
./scripts/install-termux.sh --copy-to /path/to/phone/Download \
    path/to/termux-app.apk
```

After copying, open the APK on the phone and confirm the Android package
installer prompt. The phone may require allowing the file manager to install
unknown apps. If the phone storage is not mounted, copy the APK by MTP or
another user-approved file-transfer method, then open it on the phone.

## Package order

Install the main `termux-app` APK first. Install companion APKs such as
Termux:API, Termux:Boot, or Termux:Tasker afterward. They must use the same
signing key and compatible versions as the main Termux app.

## Signing

Release APKs must be signed with the key already used by the installed Termux
family. Keep the keystore and passwords outside Git. See the signing notes in
the `termux-app` submodule for the local build workflow.
