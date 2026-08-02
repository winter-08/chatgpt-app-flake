{
  lib,
  appimageTools,
  fetchurl,
  makeWrapper,
}:

let
  pname = "codex-app";
  version = "26.727.51351";

  src = fetchurl {
    url = "https://github.com/am-will/codex-app/releases/download/v26.727.51351/codex-app-linux-x64-v26.727.51351.AppImage";
    hash = "sha256-pAHfTUB+lo1q4/WCFnwFMX/whdKe5kHYiLJOgTtcPu4=";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = lib.lists.singleton makeWrapper;

  extraInstallCommands = /* bash */ ''
    if [ -d "${appimageContents}/usr/share/icons" ]; then
      mkdir -p "$out/share"
      cp -r "${appimageContents}/usr/share/icons" "$out/share/"
    fi

    mkdir -p "$out/share/applications"
    if [ -d "${appimageContents}/usr/share/applications" ]; then
      cp -r "${appimageContents}/usr/share/applications/." "$out/share/applications/"
    else
      find "${appimageContents}" -maxdepth 2 -name '*.desktop' -exec cp {} "$out/share/applications/" \;
    fi

    for desktop_file in "$out"/share/applications/*.desktop; do
      [ -e "$desktop_file" ] || continue
      substituteInPlace "$desktop_file" \
        --replace-fail "Exec=/usr/bin/env ELECTRON_OZONE_PLATFORM_HINT=x11 Codex --ozone-platform=x11 %u" \
          "Exec=${pname} %u"
    done

    mv "$out/bin/${pname}" "$out/bin/.${pname}-wrapped"
    makeWrapper "$out/bin/.${pname}-wrapped" "$out/bin/${pname}" \
      --add-flags "--ozone-platform=x11" \
      --add-flags "--use-gl=angle" \
      --add-flags "--use-angle=swiftshader"
  '';

  meta = {
    description = "Codex desktop app packaged from am-will/codex-app Linux releases";
    homepage = "https://github.com/am-will/codex-app";
    license = lib.licenses.unfree;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
