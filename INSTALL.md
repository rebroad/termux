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

For the customized main app, the collection build script uses the configured
private signing key and places the APK in the external build tree:

```sh
./scripts/build-termux.sh
```

The installed app provides `termux-identity USERNAME HOSTNAME` to configure
the username and hostname without a first-run GUI.

## Install

Build the APKs in the relevant submodule first, connect the phone by USB (or
make its Wi-Fi debugging endpoint available), then simply run:

```sh
./scripts/install-termux.sh
```

The script finds the newest APK for each filename under this collection. It
uses any already-connected USB or Wi-Fi ADB transport. If several authorised
devices are connected, it asks which one to use. `--serial SERIAL` can select
one non-interactively.

## USB or Wi-Fi debugging enabled

On the phone, enable **Developer options → USB debugging**, connect the USB
cable, and approve the computer-authorisation prompt. Verify the device:

```sh
adb devices
```

The script uses `adb install -r`, preserving the application data. You can
also pass explicit APK paths instead of using automatic discovery:

```sh
./scripts/install-termux.sh --serial SERIAL path/to/termux-app.apk
```

## Isolated virtual-display testing

To test Termux without taking over the phone's primary display, use the
scrcpy virtual-display helper:

```sh
./scripts/termux-virtual-display.sh
```

It selects the only authorised ADB device automatically, or asks which device
to use when several are connected. The helper starts Termux on a separate
Android virtual display; close scrcpy to remove it. Use `--headless` when no
local video window is wanted. Use the customized scrcpy fork, which keeps the
keyboard on new virtual displays even in headless mode.
The helper looks for `scrcpy` in `PATH`, the
standard `~/src/scrcpy` build locations, and `/var/tmp/scrcpy-build`; set
`SCRCPY_BIN` and `SCRCPY_SERVER_PATH` when using a custom build.

## USB debugging disabled

ADB cannot install an APK when debugging is disabled. The script therefore
falls back to mounted phone storage, choosing a `Download` directory when one
is visible through MTP/GVFS. You can also specify it explicitly:

```sh
./scripts/install-termux.sh --copy-to /path/to/phone/Download
```

After copying, open the APK on the phone and confirm the Android package
installer prompt. The phone may require allowing the file manager to install
unknown apps. If the phone storage is not mounted, copy the APK by MTP or
another user-approved file-transfer method, then rerun the script.

## Package order

Install the main `termux-app` APK first. Install companion APKs such as
Termux:API, Termux:Boot, or Termux:Tasker afterward. They must use the same
signing key and compatible versions as the main Termux app.

## Signing

Release APKs must be signed with the key already used by the installed Termux
family. Keep the keystore and passwords outside Git. See the signing notes in
the `termux-app` submodule for the local build workflow.
