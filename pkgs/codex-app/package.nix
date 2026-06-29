{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "codex-app";
  version = "26.623.42028";

  src = fetchurl {
    url = "https://github.com/am-will/codex-app/releases/download/v26.623.42028/codex-app-linux-x64-v26.623.42028.AppImage";
    hash = "sha256-YGiWAmUhgbdsRX/B0VABdX047QNR8jIIbpMYiuaIX2E=";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
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
        --replace "Exec=AppRun" "Exec=${pname}" \
        --replace "Exec=codex" "Exec=${pname}" \
        --replace "Exec=codex-app" "Exec=${pname}"
    done
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
