{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  version = "0.1.80";

  assets = {
    x86_64-linux = {
      url = "https://github.com/donetick/donetick/releases/download/v${version}/donetick_Linux_x86_64.tar.gz";
      hash = "sha256:06ddrqgszwkbbacwi7l1w49bwllqj6rl6z0wirpslw5kvjbdhhx8";
    };
    aarch64-linux = {
      url = "https://github.com/donetick/donetick/releases/download/v${version}/donetick_Linux_arm64.tar.gz";
      hash = "sha256:10gm77ybpa7jal9yl762ipnsf8swrp7hr0bdbay1yf7b806ralzr";
    };
  };

  asset = assets.${stdenv.hostPlatform.system} or (throw "unsupported platform: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation rec {
  pname = "donetick";
  inherit version;

  src = fetchurl {
    inherit (asset) url hash;
  };

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/donetick
    cp donetick $out/bin/donetick
    cp -r config $out/share/donetick/config

    runHook postInstall
  '';

  meta = {
    description = "Open-source task and chore management application";
    homepage = "https://github.com/donetick/donetick";
    license = lib.licenses.agpl3Only;
    maintainers = [ ];
    mainProgram = "donetick";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
