{
  lib,
  stdenv,
  writeShellScriptBin,
  package,
  secrets,
  extraEnvironment,
  environmentFile ? null,
}:

let
  inherit (lib) optionalString;

  # Map each secret file option to the environment variable it feeds.
  secretMappings = [
    { file = secrets.jwtSecretFile; var = "DT_JWT_SECRET"; }
    { file = secrets.telegramTokenFile; var = "DONETICK_TELEGRAM_TOKEN"; }
    { file = secrets.pushoverTokenFile; var = "DONETICK_PUSHOVER_TOKEN"; }
    { file = secrets.databasePasswordFile; var = "DT_DATABASE_PASSWORD"; }
    { file = secrets.emailKeyFile; var = "DT_EMAIL_KEY"; }
    { file = secrets.storageAccessKeyFile; var = "DT_STORAGE_ACCESS_KEY"; }
    { file = secrets.storageSecretKeyFile; var = "DT_STORAGE_SECRET_KEY"; }
    { file = secrets.googleClientIdFile; var = "DT_DONETICK_CLOUD_GOOGLE_CLIENT_ID"; }
    { file = secrets.googleAndroidClientIdFile; var = "DT_DONETICK_CLOUD_GOOGLE_ANDROID_CLIENT_ID"; }
    { file = secrets.googleIosClientIdFile; var = "DT_DONETICK_CLOUD_GOOGLE_IOS_CLIENT_ID"; }
    { file = secrets.appleClientIdFile; var = "DT_DONETICK_CLOUD_APPLE_CLIENT_ID"; }
    { file = secrets.oauth2ClientIdFile; var = "DT_OAUTH2_CLIENT_ID"; }
    { file = secrets.oauth2ClientSecretFile; var = "DT_OAUTH2_CLIENT_SECRET"; }
  ];

  # Build shell fragments that read a file (if configured) and export the var.
  secretLoader = map
    ({ file, var }:
      optionalString (file != null) ''
        if [[ -r "${file}" ]]; then
          export ${var}="$(cat "${file}")"
        else
          echo "donetick: secret file ${file} is not readable" >&2
          exit 1
        fi
      '')
    secretMappings;
in

stdenv.mkDerivation {
  pname = "donetick-wrapped";
  inherit (package) version;

  nativeBuildInputs = [ ];

  buildCommand = ''
    mkdir -p $out/bin

    cat > $out/bin/donetick <<EOF
    #!${stdenv.shell}
    set -euo pipefail

    ${optionalString (environmentFile != null) ''
    if [[ -r "${environmentFile}" ]]; then
      set -a
      # shellcheck source=/dev/null
      . "${environmentFile}"
      set +a
    fi
    ''}

    ${lib.concatStringsSep "\n" secretLoader}

    exec ${lib.getExe package} "\$@"
    EOF

    chmod +x $out/bin/donetick
  '';

  meta = package.meta // {
    mainProgram = "donetick";
  };
}
