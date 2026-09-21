# Termux build collection

This repository ties together the rebroad Termux application repositories as
Git submodules. It contains shared installation documentation and scripts;
each submodule retains its own upstream history, build system, and releases.

See [INSTALL.md](INSTALL.md) for USB installation with or without ADB
debugging.

Build the signed customized app with:

```sh
./scripts/build-termux.sh
```

After installation, configure the displayed identity from inside Termux:

```sh
termux-identity USERNAME HOSTNAME
```
