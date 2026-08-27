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
and `nix build .#chatgpt-app`, opens a PR, and enables squash auto-merge when
the repository allows it. If auto-merge is disabled, the workflow succeeds
with a warning and leaves the PR open for manual review and merge. If upstream
releases and the pinned hash goes stale, builds fail with a hash mismatch until
the update PR lands.

To enable automatic merging, turn on **Settings > General > Pull Requests >
Allow auto-merge** in the repository. Configure required checks or reviews on
the target branch if they must pass before merging.

For PR CI to run without manual approval, set a repository secret named
`CHATGPT_APP_UPDATE_TOKEN` to a personal access token or GitHub App token with
permissions to create PRs and merge them. Without that secret, the workflow
falls back to `GITHUB_TOKEN`; GitHub requires a user with write access to
approve the resulting PR workflow runs. See GitHub's
[workflow trigger documentation](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow#triggering-a-workflow-from-a-workflow).

The auto-merge handling can be tested locally without GitHub access:

```sh
bash tests/enable-update-auto-merge.sh
```
