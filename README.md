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
and `nix build .#chatgpt-app`, and commits the result straight to `main` once
those checks pass. If upstream releases and the pinned hash goes stale, builds
fail with a hash mismatch until the next update lands.

The update job pushes with `GITHUB_TOKEN`, so that push does not start a CI
run: GitHub never triggers workflows from events created by `GITHUB_TOKEN`, to
keep workflows from retriggering themselves. The flake check and build run
inside the update job instead, so the pin is verified before it is committed.

This is also why the workflow commits directly rather than opening a pull
request. A PR created with `GITHUB_TOKEN` cannot start its own CI run, so the
check sat unapproved until it expired and the PR merged on a red X anyway. To
restore a reviewable PR flow, set a repository secret holding a personal access
token or GitHub App token and use it for both the checkout and the PR step; see
GitHub's
[workflow trigger documentation](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow#triggering-a-workflow-from-a-workflow).
