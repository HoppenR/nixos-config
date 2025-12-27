{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
let
  asciibnnuy = lib.strings.escapeShellArg ''
    _  _ ___ __  __           ___  ___
    | \| |_ _|\ \/ /  (\_/)   / _ \/ __|
    | .`  | |  >  <  (='.'=) | (_) \__ \
    |_|\_|___|/_/\_\ (")_(")  \___/|___/
  '';
  mainUser = "mainuser";
  cloudflareTunnelId = "07345750-570c-427b-910b-31c6cbba2ce2";
  domainName = "hoppenr.xyz";
  streamsPort = 8181;
  databases = [
    "booklore"
    "vaultwarden"
  ];
  hosts = import ./hosts.nix;
in
{
  imports = [
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
    defaultSopsFile = ./secrets/secrets.yaml;
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
      "${mainUser}" = {
        extraGroups = [
          "video"
          "input"
          "disk"
          "wheel"
        ];
        hashedPasswordFile = config.sops.secrets.user-password.path;
        isNormalUser = true;
        shell = pkgs.zsh;
        openssh.authorizedKeys.keys = lib.flatten (builtins.attrValues (import ./keys.nix));
      };
      "root" = {
        hashedPassword = null;
      };
    };
  };

  programs = {
    ssh = {
      extraConfig = ''
        Host *
          AddKeysToAgent yes
          IdentityFile ~/.local/state/ssh/id_ed25519
          UserKnownHostsFile ~/.local/state/ssh/known_hosts.d/%k
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
      "${mainUser}" = import ./home.nix;
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
          root * /mnt/web
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
            user = "${mainUser}";
          };
          terminal = {
            vt = 1;
          };
        };
      };
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
      pipewire.enable = false;
      postgresql = {
        enable = true;
        ensureDatabases = databases;
        ensureUsers = map (db: {
          name = db;
          ensureDBOwnership = true;
        }) databases;
        dataDir = "/mnt/db/postgres";
        initdbArgs = [ "--data-checksums" ];
        settings = {
          listen_addresses = lib.mkForce "";
        };
      };
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
    };

  security = {
    pam.u2f = {
      enable = true;
      settings = {
        authfile = "/etc/u2f_keys";
        userpresence = 1;
      };
    };
  };

  systemd.services = {
    caddy = {
      unitConfig.RequiresMountsFor = "/mnt/web";
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

  fileSystems =
    let
      nfsOptions = [
        "_netdev"
        "hard"
        "nfsvers=4"
        "noatime"
        "retrans=2"
        "timeo=600"
        "x-systemd.automount"
      ];
      makeNfsMount =
        name:
        lib.nameValuePair "/mnt/${name}" {
          device = "${hosts."truenas".ipv4}:/mnt/tank/${name}";
          fsType = "nfs";
          options = nfsOptions;
        };
      nfsMounts = [
        "apps/booklore"
        "db/postgres"
        "web"
      ];
    in
    builtins.listToAttrs (map makeNfsMount nfsMounts);

  networking.hosts = lib.mapAttrs (_: value: [ value.ipv4 ]) hosts;
  networking.firewall.allowedTCPPorts = [ ];
  networking.firewall.allowedUDPPorts = [ ];
  networking.firewall.enable = true;

  system.stateVersion = "25.11"; # Did you read the comment?
}
