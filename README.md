# chatgpt-app-flake

Linux-only Nix flake for the official
[ChatGPT desktop app for Linux](https://learn.chatgpt.com/docs/linux/linux-app).

The package repackages the official `.deb` assets published by OpenAI
(`x86_64-linux` and `aarch64-linux`), patching the bundled Electron binaries
against nixpkgs libraries.

## Usage

```sh
nix run github:winter-08/chatgpt-app-flake
```

For local development:

```sh
nix flake check
nix run .#update-chatgpt-app
```

## Wayland

Upstream calls native Wayland support experimental, so the app runs through
XWayland by default. To opt into native Wayland, set the standard
`NIXOS_OZONE_WL` environment variable (the same convention NixOS uses for
Chromium and Electron apps):

```sh
NIXOS_OZONE_WL=1 chatgpt
```

On NixOS you can make this permanent with
`environment.sessionVariables.NIXOS_OZONE_WL = "1";`. The wrapper only enables
Wayland when a Wayland session is actually running (`WAYLAND_DISPLAY` is set),
so the same install keeps working under X11.

## Updates

Upstream only publishes mutable `latest` URLs (no versioned paths), so the
package pins the deb hashes and relies on automation to keep them fresh.
`.github/workflows/update-chatgpt-app.yml` checks the upstream assets on a
daily schedule, updates `pkgs/chatgpt-app/package.nix`, runs `nix flake check`
and `nix build .#chatgpt-app`, opens a PR, and enables squash auto-merge for
that PR. If upstream releases and the pinned hash goes stale, builds fail with
a hash mismatch until the update PR lands.

If branch protection requires CI to run on bot-authored PRs, set a repository
secret named `CHATGPT_APP_UPDATE_TOKEN` with permissions to create PRs and merge
them. Without that secret, the workflow falls back to `GITHUB_TOKEN`.
