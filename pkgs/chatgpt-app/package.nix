{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  makeWrapper,
  patchelf,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  graphite2,
  gtk3,
  libdrm,
  libgbm,
  libglvnd,
  libnotify,
  libsecret,
  libusb1,
  libX11,
  libxcb,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libxkbcommon,
  libXrandr,
  nspr,
  nss,
  pango,
  systemd,
}:

let
  pname = "chatgpt-app";
  version = "26.825.32147";

  # Official Linux assets from https://learn.chatgpt.com/docs/linux/linux-app.
  # Upstream only publishes mutable "latest" URLs, so the pinned hash below is
  # what guarantees reproducibility; the update workflow refreshes both.
  baseUrl = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest";

  sources = {
    x86_64-linux = fetchurl {
      url = "${baseUrl}/chatgpt_amd64.deb";
      hash = "sha256-mG04tpDdAxCTPOYRdbCcJ0NAAfThFDMrsPe2/9w8pAY=";
    };
    aarch64-linux = fetchurl {
      url = "${baseUrl}/chatgpt_arm64.deb";
      hash = "sha256-F3X3sZt2hmTQaXxUTr3bdRT3TPVZ35FG5JisAj8lSSU=";
    };
  };

  libraries = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    graphite2
    gtk3
    libdrm
    libgbm
    libusb1
    libX11
    libxcb
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libxkbcommon
    libXrandr
    nspr
    nss
    pango
    (lib.getLib stdenv.cc.cc)
  ];

  # dlopen'd at runtime, not linked at load time.
  runtimeLibraries = [
    (lib.getLib systemd)
    libglvnd
    libnotify
    libsecret
    libusb1
  ];

  libraryPath = lib.makeLibraryPath (libraries ++ runtimeLibraries);
in
stdenv.mkDerivation {
  inherit pname version;

  src =
    sources.${stdenv.hostPlatform.system}
      or (throw "chatgpt-app: unsupported system ${stdenv.hostPlatform.system}");

  nativeBuildInputs = [
    dpkg
    makeWrapper
    patchelf
    wrapGAppsHook3
  ];

  buildInputs = libraries;

  dontConfigure = true;
  dontBuild = true;
  dontPatchELF = true;
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r usr/lib usr/share "$out/"
    # Upstream launcher script; replaced by the wrapper in $out/bin.
    rm "$out/lib/chatgpt/codex-launcher"

    # Node's diagnostic report (process.report.getReport, called on startup by
    # the bundled detect-libc) does dlsym(RTLD_DEFAULT, "gnu_get_libc_version")
    # and calls the result. This Electron is built with Clang CFI-icall, whose
    # check only accepts targets inside the binary's own jump table -- the
    # glibc address returned by dlsym never is, so the call traps with SIGILL
    # on any glibc system that reaches it. Rename the .rodata dlsym string so
    # the lookup fails and the code takes its graceful NULL path; the .dynstr
    # copy (the real dynamic import, resolved via PLT) must stay intact.
    chatgptBin="$out/lib/chatgpt/ChatGPT"
    read -r dynstrOff dynstrSize < <(
      readelf -SW "$chatgptBin" \
        | sed 's/\[ *[0-9]*\]//' \
        | awk '$1 == ".dynstr" { print strtonum("0x" $4), strtonum("0x" $5) }'
    )
    [ -n "$dynstrOff" ] || { echo "chatgpt-app: .dynstr not found in ChatGPT" >&2; exit 1; }
    patchedLibcProbe=0
    while read -r off; do
      if (( off < dynstrOff || off >= dynstrOff + dynstrSize )); then
        printf 'nix_get_libc_version' \
          | dd of="$chatgptBin" bs=1 seek="$off" conv=notrunc status=none
        patchedLibcProbe=$(( patchedLibcProbe + 1 ))
      fi
    done < <(grep -aob 'gnu_get_libc_version' "$chatgptBin" | cut -d: -f1)
    if (( patchedLibcProbe == 0 )); then
      echo "chatgpt-app: no gnu_get_libc_version dlsym string found to patch" >&2
      exit 1
    fi

    # Electron's Node diagnostic report parser traps if autoPatchelf rewrites
    # this executable's unusual ELF string table. Patch only the interpreter
    # and runpath, without autoPatchelf's dependency rewriting or shrinking.
    find "$out/lib/chatgpt" -type f \
      \( -perm -0100 -o -name '*.so*' -o -name '*.node' \) -print0 \
      | while IFS= read -r -d "" file; do
          # Skip static binaries, including static-PIE ones like
          # resources/codex that have a DYNAMIC section but no DT_NEEDED:
          # they need no interpreter or runpath, and patchelf's dynamic
          # section rewrite breaks static-PIE self-relocation (SIGSEGV).
          if [ -z "$(patchelf --print-needed "$file" 2> /dev/null)" ]; then
            continue
          fi

          if patchelf --print-interpreter "$file" > /dev/null 2>&1; then
            patchelf --set-interpreter "$(cat "$NIX_CC/nix-support/dynamic-linker")" "$file"
          fi

          patchelf --set-rpath "${libraryPath}:$out/lib/chatgpt" "$file"
        done

    runHook postInstall
  '';

  # gappsWrapperArgs is only populated during fixup, so wrap here rather than
  # in installPhase. makeShellWrapper (not the binary wrapper wrapGAppsHook3
  # pulls in) is required for the runtime ''${NIXOS_OZONE_WL:+…} expansion.
  preFixup = ''
    mkdir -p "$out/bin"
    makeShellWrapper "$out/lib/chatgpt/ChatGPT" "$out/bin/chatgpt" \
      "''${gappsWrapperArgs[@]}" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
  '';

  meta = {
    description = "ChatGPT desktop app for Linux, repackaged from the official deb";
    homepage = "https://chatgpt.com/";
    downloadPage = "https://learn.chatgpt.com/docs/linux/linux-app";
    license = lib.licenses.unfree;
    mainProgram = "chatgpt";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
