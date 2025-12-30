{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  asciibnnuy = lib.strings.escapeShellArg ''
    _  _ ___ __  __           ___  ___
    | \| |_ _|\ \/ /  (\_/)   / _ \/ __|
    | .`  | |  >  <  (='.'=) | (_) \__ \
    |_|\_|___|/_/\_\ (")_(")  \___/|___/
  '';
  cloudflareTunnelId = "07345750-570c-427b-910b-31c6cbba2ce2";
  domainName = "hoppenr.xyz";
  streamsPort = 8181;
  databases = [
    "booklore"
    "vaultwarden"
  ];
  roles = import ../../roles { inherit lib; };

  mainuserHome = config.home-manager.users.mainuser;
in
{
  _module.args.roles = roles;
  imports = [
    ../common/options.nix
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
  ];

  environment = {
    shellAliases = {
      l = null;
      ll = "ls --almost-all -lh";
      ls = "ls --color=auto";
    };
    systemPackages = builtins.attrValues {
      inherit (pkgs)
        gcc
        glibc
        sops
        xfsprogs
        yubikey-manager
        ;
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Europe/Stockholm";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "sv_SE.UTF-8";
    LC_MONETARY = "sv_SE.UTF-8";
    LC_MEASUREMENT = "sv_SE.UTF-8";
    LC_PAPER = "sv_SE.UTF-8";
    LC_NUMERIC = "sv_SE.UTF-8";
  };
  console = {
    packages = builtins.attrValues {
      inherit (pkgs)
        terminus_font
        ;
    };
    font = "Lat2-Terminus16";
    keyMap = "sv-latin1";
  };

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    # created by services.openssh.hostKeys
    age.sshKeyPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
    gnupg.sshKeyPaths = [ ];
    secrets = {
      user-password.neededForUsers = true;
      "streamserver-client-id".key = "streamserver/client-id";
      "streamserver-client-secret".key = "streamserver/client-secret";
      "cloudflare-account-tag".key = "cloudflare/account-tag";
      "cloudflare-tunnel-secret".key = "cloudflare/tunnel-secret";
      "cloudflare-api-token".key = "cloudflare/api-token";
    };
    templates = {
      "streamserver-env" = {
        content = ''
          CLIENT_ID=${config.sops.placeholder."streamserver-client-id"}
          CLIENT_SECRET=${config.sops.placeholder."streamserver-client-secret"}
          USER_NAME=hoppenr
        '';
        restartUnits = [ "podman-streamserver.service" ];
      };
      "cloudflare-tunnel-config" = {
        content = ''
          {
            "AccountTag": "${config.sops.placeholder."cloudflare-account-tag"}",
            "TunnelSecret": "${config.sops.placeholder."cloudflare-tunnel-secret"}",
            "TunnelID": "${cloudflareTunnelId}"
          }
        '';
      };
      "caddy-dns-config" = {
        owner = config.users.users.caddy.name;
        group = config.users.users.caddy.group;
        content = ''
          tls {
            dns cloudflare ${config.sops.placeholder.cloudflare-api-token}
          }
        '';
      };
    };
  };

  users = {
    mutableUsers = false;
    users = {
      mainuser = {
        extraGroups = [
          "video"
          "input"
          "disk"
          "wheel"
        ];
        hashedPasswordFile = config.sops.secrets.user-password.path;
        isNormalUser = true;
        shell = pkgs.zsh;
        openssh.authorizedKeys.keys = roles."${config.networking.role}".authorizedKeys;
      };
      "root" = {
        hashedPassword = null;
      };
    };
  };

  programs = {
    ssh = {
      knownHosts = {
        # For running zrepl job -> storage
        "${roles.storage.hostName}" = {
          extraHostNames = [ "${roles.storage.ipv4}" ];
          publicKey = roles.storage.publicKey;
        };
      };
      extraConfig =
        let
          mainUserStatePath =
            if mainuserHome.xdg.enable then
              config.home-manager.users.mainuser.xdg.stateHome
            else
              "${mainuserHome.home.homeDirectory}/.local/state";
        in
        ''
          Match localuser ${mainuserHome.home.username}
            AddKeysToAgent yes
            IdentityFile ${mainUserStatePath}/ssh/id_ed25519
            UserKnownHostsFile ${mainUserStatePath}/ssh/known_hosts.d/%k
          Match localuser root
            IdentityFile /persist/etc/ssh/ssh_host_ed25519_key
        '';
    };
    zsh.enable = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs; };
    users = {
      mainuser = import ./home.nix;
    };
  };

  fonts.packages = builtins.attrValues {
    inherit (pkgs.nerd-fonts)
      jetbrains-mono
      ;
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    allowed-users = [ "@wheel" ];
  };

  services =
    let
      getFqdn = name: if name == "@" then domainName else "${name}.${domainName}";
      caddyEndpoints = lib.mapAttrs' (n: v: lib.nameValuePair (getFqdn n) v) {
        "@" = ''
          root * /replicated/web
          file_server browse
        '';
        "streams" = "reverse_proxy localhost:${toString streamsPort}";
        "vaultwarden" = ''
          reverse_proxy localhost:${toString config.services.vaultwarden.config.ROCKET_PORT}
        '';
        "www" = "redir https://${domainName}{uri}";
      };
      makeVirtualHost =
        hostname: extraConfig:
        lib.nameValuePair hostname {
          extraConfig = ''
            import ${config.sops.templates."caddy-dns-config".path}
            ${extraConfig}
          '';
        };
      makeCaddyIngress =
        hostname: _:
        lib.nameValuePair hostname {
          service = "https://localhost:443";
          originRequest.originServerName = hostname;
        };
    in
    {
      caddy = {
        enable = true;
        package = pkgs.caddy.withPlugins {
          plugins = [ "github.com/caddy-dns/cloudflare@v0.2.2" ];
          hash = "sha256-ea8PC/+SlPRdEVVF/I3c1CBprlVp1nrumKM5cMwJJ3U=";
        };
        virtualHosts = lib.mapAttrs' makeVirtualHost caddyEndpoints;
      };
      cloudflared = {
        enable = true;
        tunnels = {
          "${cloudflareTunnelId}" = {
            credentialsFile = config.sops.templates."cloudflare-tunnel-config".path;
            ingress = (lib.mapAttrs' makeCaddyIngress caddyEndpoints) // {
              "${getFqdn "ssh"}" = "ssh://localhost:22";
            };
            default = "http_status:503";
          };
        };
      };
      greetd = {
        enable = true;
        settings = {
          default_session = {
            command = ''
              ${lib.getExe pkgs.tuigreet} \
                --cmd "zsh --login" \
                --greeting ${asciibnnuy} \
                --user-menu \
                --time \
                --time-format %R
            '';
          };
          terminal = {
            vt = 1;
          };
        };
      };
      pipewire.enable = false;
      resolved.enable = true;
      openssh = {
        enable = true;
        hostKeys = [
          {
            path = "/persist/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
        settings = {
          AllowAgentForwarding = false;
          AuthenticationMethods = "publickey";
          KbdInteractiveAuthentication = false;
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };
      pcscd.enable = true;
      postgresql = {
        enable = true;
        ensureDatabases = databases;
        ensureUsers = map (db: {
          name = db;
          ensureDBOwnership = true;
        }) databases;
        dataDir = "/replicated/db/postgres";
        initdbArgs = [ "--data-checksums" ];
        settings = {
          listen_addresses = lib.mkForce "";
        };
      };
      # syncthing = {
      #   enable = true;
      #   user = "mainuser";
      #   configDir = "/var/lib/syncthing";
      #   dataDir = "/replicated/apps/syncthing";
      # };
      udev = {
        packages = builtins.attrValues {
          inherit (pkgs)
            yubikey-personalization
            ;
        };
      };
      vaultwarden = {
        enable = true;
        dbBackend = "postgresql";
        config = {
          DATABASE_URL = "postgresql://vaultwarden@%2Frun%2Fpostgresql/vaultwarden";
          DOMAIN = "https://vaultwarden.${domainName}";
          SIGNUPS_ALLOWED = false;
          ROCKET_ADDRESS = "::1";
          ROCKET_PORT = 8222;
        };
      };
      zrepl = {
        enable = true;
        settings = {
          jobs = [
            {
              name = "push_db_${roles.storage.hostName}";
              type = "push";
              connect = {
                host = "${roles.storage.ipv4}";
                identity_file = "/persist/etc/ssh/ssh_host_ed25519_key";
                port = 22;
                type = "ssh+stdinserver";
                user = "root";
              };
              filesystems = {
                "tank/replicated/db<" = true;
              };
              replication = {
                # https://zrepl.github.io/configuration/sendrecvoptions.html#job-note-property-replication
                # Receiver might want this:
                # recv.properties.override = {
                #   mountpoint = "none"
                #   canmount = "off";
                # };
                # send = {
                #   properties = true;
                # };
                protection = {
                  initial = "guarantee_resumability";
                  incremental = "guarantee_incremental";
                };
              };
              pruning = {
                keep_sender = [
                  { type = "not_replicated"; }
                  {
                    type = "last_n";
                    count = 4;
                  }
                ];
                keep_receiver = [
                  {
                    type = "grid";
                    grid = "1x24h(keep=all) | 6x1d | 3x1w | 3x30d";
                    regex = "^zrepl_";
                  }
                ];
              };
              snapshotting = {
                interval = "1d";
                prefix = "zrepl_";
                timestamp_format = "iso_8601";
                type = "periodic";
              };
            }
          ];
        };
      };
    };

  security = {
    pam.u2f = {
      enable = true;
      settings = {
        authfile = "/etc/u2f_keys";
        userpresence = 1;
      };
    };
    polkit.enable = true;
  };

  systemd.services = {
    caddy = {
      unitConfig.RequiresMountsFor = "/replicated/web";
    };
    vaultwarden = {
      after = [ "postgresql.service" ];
      requires = [ "postgresql.service" ];
    };
  };

  virtualisation = {
    podman.autoPrune = {
      enable = true;
      dates = "weekly";
    };
    oci-containers = {
      backend = "podman";
      containers = {
        streamserver = {
          autoStart = true;
          image = "ghcr.io/hoppenr/streamserver:latest";
          ports = [ "${toString streamsPort}:8181" ];
          environmentFiles = [ config.sops.templates."streamserver-env".path ];
        };
      };
    };
  };

  networking.hostId = "8425e349";
  networking.hostName = roles."${config.networking.role}".hostName;
  networking.hosts = lib.mapAttrs' (_: host: lib.nameValuePair host.ipv4 [ host.hostName ]) (
    lib.filterAttrs (role: host: (host ? ipv4) && (role != config.networking.role)) roles
  );
  networking.role = "logic";
  networking.firewall.allowedTCPPorts = [ ];
  networking.firewall.allowedUDPPorts = [ ];
  networking.firewall.enable = true;

  system.stateVersion = "25.11"; # Did you read the comment?
}
