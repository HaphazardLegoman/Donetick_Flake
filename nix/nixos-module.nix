{ self }:

{ config, lib, pkgs, ... }:

let
  cfg = config.services.donetick;

  inherit (lib)
    mkEnableOption
    mkOption
    mkPackageOption
    mkIf
    types
    literalExpression
    optionalString
    optionalAttrs
    mapAttrsToList
    concatStringsSep
    ;

  # Build a donetick package that knows how to load secret files.
  donetickWithSecrets = pkgs.callPackage ./wrapper.nix {
    inherit (cfg) package secrets extraEnvironment environmentFile;
  };

  boolToString = b: if b then "true" else "false";

  maybeEnv = name: value:
    if value == null then null
    else lib.nameValuePair name value;

  optionalEnv = name: value: lib.optionalAttrs (value != null) { ${name} = value; };

  optionalEnvList = lib.filter (x: x != null) [
    (maybeEnv "DT_ENV" cfg.name)
    (maybeEnv "DT_SQLITE_PATH" cfg.sqlitePath)
    (maybeEnv "DT_DATABASE_TYPE" cfg.database.type)
    (maybeEnv "DT_SINGLE_CIRCLE_INSTANCE" (if cfg.singleCircleInstance then "true" else null))
    (maybeEnv "DT_DISABLE_PASSWORD_AUTH" (if cfg.disablePasswordAuth then "true" else null))
    (maybeEnv "DT_OAUTH2_ADMIN_GROUPS" (concatStringsSep "," cfg.oauth2.adminGroups))
    (maybeEnv "DT_OAUTH2_MANAGER_GROUPS" (concatStringsSep "," cfg.oauth2.managerGroups))
    (maybeEnv "DT_DISABLE_SIGNUP" (if cfg.userCreationDisabled then "true" else null))
  ];

  baseEnvironment = lib.listToAttrs optionalEnvList // cfg.extraEnvironment;

  # Non-secret configuration is passed as environment variables. Viper maps
  # DT_<KEY> onto the YAML path using underscores, so this mirrors the config
  # file semantics without storing secrets in the Nix store.
  configEnvironment = lib.filterAttrs (_: v: v != null) {
    # Database
    DT_DATABASE_HOST = cfg.database.host;
    DT_DATABASE_PORT = if cfg.database.port == null then null else toString cfg.database.port;
    DT_DATABASE_USER = cfg.database.user;
    DT_DATABASE_NAME = cfg.database.name;
    DT_DATABASE_MIGRATION = boolToString cfg.database.migration;
    DT_DATABASE_LOGGER = if cfg.database.logLevel == null then null else toString cfg.database.logLevel;

    # JWT
    DT_JWT_SESSION_TIME = cfg.jwt.sessionTime;
    DT_JWT_MAX_REFRESH = cfg.jwt.maxRefresh;

    # Server
    DT_SERVER_PORT = toString cfg.server.port;
    DT_SERVER_READ_TIMEOUT = cfg.server.readTimeout;
    DT_SERVER_WRITE_TIMEOUT = cfg.server.writeTimeout;
    DT_SERVER_RATE_PERIOD = cfg.server.ratePeriod;
    DT_SERVER_RATE_LIMIT = toString cfg.server.rateLimit;
    DT_SERVER_SERVE_FRONTEND = boolToString cfg.server.serveFrontend;
    DT_SERVER_SERVE_SWAGGER = boolToString cfg.server.serveSwagger;
    DT_SERVER_PUBLIC_HOST = cfg.server.publicHost;

    # Scheduler
    DT_SCHEDULER_JOBS_DUE_JOB = cfg.schedulerJobs.dueJob;
    DT_SCHEDULER_JOBS_OVERDUE_JOB = cfg.schedulerJobs.overdueJob;
    DT_SCHEDULER_JOBS_PRE_DUE_JOB = cfg.schedulerJobs.preDueJob;

    # Email
    DT_EMAIL_HOST = cfg.email.host;
    DT_EMAIL_PORT = if cfg.email.port == null then null else toString cfg.email.port;
    DT_EMAIL_EMAIL = cfg.email.email;
    DT_EMAIL_USER = cfg.email.user;
    DT_EMAIL_APP_HOST = cfg.email.appHost;
    DT_EMAIL_LOG_RAW_URL = boolToString cfg.email.logRawUrl;
    DT_EMAIL_PROVIDER = cfg.email.provider;
    DT_EMAIL_VERIFY_TEMPLATE_ID = cfg.email.verifyTemplateId;
    DT_EMAIL_RESET_PASSWORD_TEMPLATE_ID = cfg.email.resetPasswordTemplateId;

    # MFA
    DT_MFA_ENABLED = boolToString cfg.mfa.enabled;
    DT_MFA_SESSION_TIMEOUT_MINUTES = toString cfg.mfa.sessionTimeout;
    DT_MFA_BACKUP_CODE_COUNT = toString cfg.mfa.backupCodeCount;
    DT_MFA_MAX_VERIFICATION_ATTEMPTS = toString cfg.mfa.maxVerificationAttempts;
    DT_MFA_RATE_LIMIT_WINDOW = cfg.mfa.rateLimitWindow;

    # Storage
    DT_STORAGE_STORAGE_TYPE = cfg.storage.type;
    DT_STORAGE_MAX_USER_STORAGE = toString cfg.storage.maxUserStorage;
    DT_STORAGE_MAX_FILE_SIZE = toString cfg.storage.maxFileSize;
    DT_STORAGE_BUCKET_NAME = cfg.storage.bucketName;
    DT_STORAGE_REGION = cfg.storage.region;
    DT_STORAGE_BASE_PATH = cfg.storage.basePath;
    DT_STORAGE_ENDPOINT = cfg.storage.endpoint;
    DT_STORAGE_PUBLIC_HOST = cfg.storage.publicHost;
    DT_STORAGE_PUBLIC_READ = boolToString cfg.storage.publicRead;
    DT_STORAGE_PUBLIC_BUCKET_NAME = cfg.storage.publicBucketName;
    DT_STORAGE_PUBLIC_BUCKET_HOST = cfg.storage.publicBucketHost;
    DT_STORAGE_PATH_STYLE = boolToString cfg.storage.pathStyle;

    # OAuth2
    DT_OAUTH2_REDIRECT_URL = cfg.oauth2.redirectUrl;
    DT_OAUTH2_PKCE = boolToString cfg.oauth2.pkce;
    DT_OAUTH2_AUTH_URL = cfg.oauth2.authUrl;
    DT_OAUTH2_TOKEN_URL = cfg.oauth2.tokenUrl;
    DT_OAUTH2_USER_INFO_URL = cfg.oauth2.userInfoUrl;
    DT_OAUTH2_NAME = cfg.oauth2.name;

    # Logging
    DT_LOGGING_LEVEL = cfg.logging.level;
    DT_LOGGING_ENCODING = cfg.logging.encoding;
    DT_LOGGING_DEVELOPMENT = boolToString cfg.logging.development;
  };

  # Lists are joined with commas when passed as environment variables.
  listEnvironment = lib.filterAttrs (_: v: v != null) {
    DT_SERVER_CORS_ALLOW_ORIGINS = if cfg.server.corsAllowOrigins == null then null else concatStringsSep "," cfg.server.corsAllowOrigins;
    DT_OAUTH2_SCOPES = if cfg.oauth2.scopes == null then null else concatStringsSep "," cfg.oauth2.scopes;
  };

  serviceEnvironment = baseEnvironment // configEnvironment // listEnvironment;
in
{
  options.services.donetick = {
    enable = mkEnableOption "Donetick task and chore management server";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ../pkgs/donetick.nix { };
      defaultText = literalExpression "pkgs.callPackage ./pkgs/donetick.nix { }";
      description = "Donetick package to use.";
    };

    user = mkOption {
      type = types.str;
      default = "donetick";
      description = "User account under which Donetick runs.";
    };

    group = mkOption {
      type = types.str;
      default = "donetick";
      description = "Group under which Donetick runs.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/donetick";
      description = "Directory where Donetick stores its SQLite database and uploads.";
    };

    sqlitePath = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to the SQLite database file. Defaults to
        {option}`dataDir`/donetick.db when null.
      '';
    };

    name = mkOption {
      type = types.str;
      default = "selfhosted";
      description = ''
        Runtime environment name, passed as `DT_ENV`. This selects the
        configuration profile used by Donetick.
      '';
    };

    userCreationDisabled = mkOption {
      type = types.bool;
      default = false;
      description = "Disable new user signups.";
    };

    singleCircleInstance = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Hide circle management and add new OIDC users to a shared household
        circle instead of creating personal circles.
      '';
    };

    disablePasswordAuth = mkOption {
      type = types.bool;
      default = false;
      description = ''
        When true, password login is disabled and the login UI hides the
        password form (SSO-only mode).
      '';
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Optional systemd-style environment file read by the service before
        secret files are loaded. Useful for additional variables not covered
        by module options.
      '';
    };

    extraEnvironment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Additional environment variables passed to Donetick. These override
        values set by other module options.
      '';
    };

    secrets = {
      jwtSecretFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to a file containing the JWT secret. Must be at least 32
          characters long. This is required for non-local deployments.
        '';
      };

      telegramTokenFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a file containing the Telegram bot token.";
      };

      pushoverTokenFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a file containing the Pushover token.";
      };

      databasePasswordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a file containing the database password.";
      };

      emailKeyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a file containing the email/SMTP password or API key.";
      };

      storageAccessKeyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a file containing the S3-compatible access key.";
      };

      storageSecretKeyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a file containing the S3-compatible secret key.";
      };

      googleClientIdFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a file containing the Google OAuth client ID.";
      };

      googleAndroidClientIdFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a file containing the Google Android client ID.";
      };

      googleIosClientIdFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a file containing the Google iOS client ID.";
      };

      appleClientIdFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a file containing the Apple client ID.";
      };

      oauth2ClientIdFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a file containing the OIDC/OAuth2 client ID.";
      };

      oauth2ClientSecretFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a file containing the OIDC/OAuth2 client secret.";
      };
    };

    database = {
      type = mkOption {
        type = types.str;
        default = "sqlite";
        description = "Database type. Either 'sqlite' or 'postgres'.";
      };

      host = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Database host (required for postgres).";
      };

      port = mkOption {
        type = types.nullOr types.port;
        default = null;
        description = "Database port (required for postgres).";
      };

      user = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Database user (required for postgres).";
      };

      name = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Database name (required for postgres).";
      };

      migration = mkOption {
        type = types.bool;
        default = true;
        description = "Enable database migrations on startup.";
      };

      logLevel = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "GORM database logger level.";
      };
    };

    jwt = {
      sessionTime = mkOption {
        type = types.str;
        default = "24h";
        description = "Access token lifetime.";
      };

      maxRefresh = mkOption {
        type = types.str;
        default = "1440h";
        description = "Maximum refresh window from original login.";
      };
    };

    server = {
      port = mkOption {
        type = types.port;
        default = 2021;
        description = "Port on which Donetick listens.";
      };

      readTimeout = mkOption {
        type = types.str;
        default = "10s";
        description = "HTTP read timeout.";
      };

      writeTimeout = mkOption {
        type = types.str;
        default = "10s";
        description = "HTTP write timeout.";
      };

      ratePeriod = mkOption {
        type = types.str;
        default = "60s";
        description = "Rate limit period.";
      };

      rateLimit = mkOption {
        type = types.int;
        default = 300;
        description = "Maximum requests per rate period.";
      };

      corsAllowOrigins = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "List of allowed CORS origins.";
      };

      serveFrontend = mkOption {
        type = types.bool;
        default = true;
        description = "Serve the built-in web frontend.";
      };

      serveSwagger = mkOption {
        type = types.bool;
        default = true;
        description = "Serve Swagger UI.";
      };

      publicHost = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Publicly reachable URL of the instance.";
      };
    };

    schedulerJobs = {
      dueJob = mkOption {
        type = types.str;
        default = "30m";
        description = "Interval at which due job notifications run.";
      };

      overdueJob = mkOption {
        type = types.str;
        default = "3h";
        description = "Interval at which overdue job notifications run.";
      };

      preDueJob = mkOption {
        type = types.str;
        default = "3h";
        description = "Interval at which pre-due job notifications run.";
      };
    };

    email = {
      host = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "SMTP or email provider host.";
      };

      port = mkOption {
        type = types.nullOr types.port;
        default = null;
        description = "SMTP or email provider port.";
      };

      email = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Sender email address.";
      };

      user = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "SMTP username. Defaults to the sender email if unset.";
      };

      appHost = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Public host used in password-reset links.";
      };

      logRawUrl = mkOption {
        type = types.bool;
        default = true;
        description = "Log password reset URLs to the console.";
      };

      provider = mkOption {
        type = types.str;
        default = "smtp";
        description = "Email provider implementation: 'smtp' or 'smtp2go'.";
      };

      verifyTemplateId = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "SMTP2Go verification template ID.";
      };

      resetPasswordTemplateId = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "SMTP2Go password reset template ID.";
      };
    };

    mfa = {
      enabled = mkOption {
        type = types.bool;
        default = true;
        description = "Enable multi-factor authentication.";
      };

      sessionTimeout = mkOption {
        type = types.int;
        default = 15;
        description = "MFA session timeout in minutes.";
      };

      backupCodeCount = mkOption {
        type = types.int;
        default = 10;
        description = "Number of MFA backup codes generated.";
      };

      maxVerificationAttempts = mkOption {
        type = types.int;
        default = 5;
        description = "Maximum failed MFA verification attempts.";
      };

      rateLimitWindow = mkOption {
        type = types.str;
        default = "5m";
        description = "MFA rate limit window.";
      };
    };

    storage = {
      type = mkOption {
        type = types.str;
        default = "local";
        description = "Storage backend: 'local' or 's3'.";
      };

      maxUserStorage = mkOption {
        type = types.int;
        default = 10737418240;
        description = "Maximum per-user storage in bytes.";
      };

      maxFileSize = mkOption {
        type = types.int;
        default = 102400;
        description = "Maximum uploaded file size in bytes.";
      };

      bucketName = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "S3 bucket name.";
      };

      region = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "S3 region.";
      };

      basePath = mkOption {
        type = types.str;
        default = "./uploads";
        description = "Local storage upload path.";
      };

      endpoint = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "S3-compatible endpoint URL.";
      };

      publicHost = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Public host used for presigned URLs.";
      };

      publicRead = mkOption {
        type = types.bool;
        default = false;
        description = "Return unsigned public URLs instead of presigned URLs.";
      };

      publicBucketName = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional separate public bucket.";
      };

      publicBucketHost = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "CDN host for public bucket URLs.";
      };

      pathStyle = mkOption {
        type = types.bool;
        default = false;
        description = "Use path-style S3 addressing.";
      };
    };

    donetickCloud = {
      googleClientIdFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a file containing the Google OAuth client ID.";
      };

      googleAndroidClientIdFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a file containing the Google Android client ID.";
      };

      googleIosClientIdFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a file containing the Google iOS client ID.";
      };

      appleClientIdFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a file containing the Apple client ID.";
      };
    };

    oauth2 = {
      redirectUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "OIDC redirect URL.";
      };

      pkce = mkOption {
        type = types.bool;
        default = false;
        description = "Enable PKCE for OIDC.";
      };

      scopes = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "OIDC scopes to request.";
      };

      authUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "OIDC authorization endpoint.";
      };

      tokenUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "OIDC token endpoint.";
      };

      userInfoUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "OIDC userinfo endpoint.";
      };

      name = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Display name for the OIDC provider.";
      };

      adminGroups = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "OIDC groups that grant the admin role.";
      };

      managerGroups = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "OIDC groups that grant the manager role.";
      };
    };

    logging = {
      level = mkOption {
        type = types.str;
        default = "info";
        description = "Log level: debug, info, warn, error, etc.";
      };

      encoding = mkOption {
        type = types.str;
        default = "json";
        description = "Log encoding: 'console' or 'json'.";
      };

      development = mkOption {
        type = types.bool;
        default = false;
        description = "Enable development logging mode.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.name != "local" -> cfg.secrets.jwtSecretFile != null;
        message = "services.donetick.secrets.jwtSecretFile must be set when name is not 'local'";
      }
    ];

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
      description = "Donetick service user";
    };

    users.groups.${cfg.group} = { };

    systemd.services.donetick = {
      description = "Donetick task and chore management server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        StateDirectory = baseNameOf cfg.dataDir;
        StateDirectoryMode = "0750";
        ExecStart = lib.getExe donetickWithSecrets;
        Restart = "on-failure";
        RestartSec = "5";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
      } // lib.optionalAttrs (serviceEnvironment != { }) {
        Environment = lib.mapAttrsToList (name: value: "${name}=${toString value}") serviceEnvironment;
      } // lib.optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };
    };
  };
}
