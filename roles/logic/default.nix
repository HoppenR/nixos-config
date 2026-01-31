{
  config,
  lib,
  pkgs,
  ...
}:
let
  domainName = "hoppenr.xyz";
  mainUser = "mainuser";
  streamsPort = 8181;
in
{
  _module.args = {
    inherit mainUser;
  };

  imports = [
    ../common
    ./booklore.nix
  ];

  console.colors = lib.attrValues {
    c01_black = "2e3440";
    c02_red = "bf616a";
    c03_green = "a3be8c";
    c04_yellow = "ebcb8b";
    c05_blue = "81a1c1";
    c06_magenta = "01145e";
    c07_cyan = "88c0d0";
    c08_white = "e5e9f0";
    c09_blackFg = "4c566a";
    c10_redFg = "bf616a";
    c11_greenFg = "a3be8c";
    c12_yellowFg = "ebcb8b";
    c13_blueFg = "88c0d0";
    c14_magentaFg = "b48ead";
    c15_cyanFg = "8fbcbb";
    c16_whiteFg = "eceff4";
  };

  environment = {
    systemPackages = builtins.attrValues {
      inherit (pkgs)
        mailutils
        ;
    };
  };

  home-manager = {
    users = {
      ${mainUser} = import ../../home/logic.nix;
    };
  };

  lab = {
    booklore = {
      enable = true;
    };
    greetd = {
      enable = true;
      theme = "container=blue;window=black;border=magenta;greet=magenta;prompt=magenta;input=magenta;action=blue";
      useZshLogin = true;
    };
  };

  services =
    let
      getFqdn = name: if name == "@" then domainName else "${name}.${domainName}";
      caddyEndpoints = lib.mapAttrs' (n: v: lib.nameValuePair (getFqdn n) v) {
        "@" = ''
          root * /replicated/web
          file_server browse

          handle_path /api/* {
              reverse_proxy https://strims.gg {
                  header_up Host strims.gg
                  header_up X-Real-IP {remote_host}
              }
          }
        '';
        "streams" = "reverse_proxy localhost:${toString streamsPort}";
        "vaultwarden" = ''
          reverse_proxy localhost:${toString config.services.vaultwarden.config.ROCKET_PORT}
        '';
        "www" = "redir https://${domainName}{uri}";
        "booklore" = "reverse_proxy localhost:6060";
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
          hash = "sha256-dnhEjopeA0UiI+XVYHYpsjcEI6Y1Hacbi28hVKYQURg=";
        };
        virtualHosts = lib.mapAttrs' makeVirtualHost caddyEndpoints;
      };
      cloudflared = {
        enable = true;
        tunnels = {
          "${domainName}" = {
            credentialsFile = config.sops.templates."cloudflare-tunnel-config".path;
            ingress = (lib.mapAttrs' makeCaddyIngress caddyEndpoints) // {
              "${getFqdn "ssh"}" = "ssh://localhost:22";
            };
            default = "http_status:503";
          };
        };
      };
      pipewire.enable = false;
      openssh = {
        # TODO: make into common and enable only when lab.sshd.enable
        enable = true;
        hostKeys = [
          {
            path = "/persist/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
        settings = {
          AuthenticationMethods = "publickey";
          KbdInteractiveAuthentication = false;
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };
      postfix = {
        enable = true;
        settings.main = {
          inet_interfaces = "loopback-only";
          relayhost = [ "[smtp.protonmail.ch]:587" ];
          smtp_generic_maps = "inline:{ { root@${config.networking.hostName} = contact@hoppenr.xyz } }";
          smtp_sasl_auth_enable = "yes";
          smtp_sasl_password_maps = "texthash:${config.sops.templates.postfix-password-map.path}";
          smtp_sasl_security_options = "noanonymous";
          smtp_tls_loglevel = "1";
          smtp_tls_note_starttls_offer = "yes";
          smtp_tls_security_level = "encrypt";
          smtp_tls_wrappermode = "no";
        };
      };
      postgresql = {
        enable = true;
        dataDir = "/replicated/db/postgres";
        initdbArgs = [ "--data-checksums" ];
        settings = {
          full_page_writes = "off";
          listen_addresses = lib.mkForce "";
        };
      };
      mysql = {
        enable = true;
        package = pkgs.mariadb;
        dataDir = "/replicated/db/mariadb";
        settings.mysqld = {
          innodb_checksum_algorithm = "crc32";
          innodb_doublewrite = 0;
          innodb_flush_method = "O_DIRECT";
          innodb_page_size = "16k";
          innodb_use_atomic_writes = 0;
          innodb_use_native_aio = 0;
          bind-address = "10.88.0.1";
        };
      };
      vaultwarden = {
        enable = true;
        dbBackend = "postgresql";
        configurePostgres = true;
        domain = "vaultwarden.${domainName}";
        config = {
          ROCKET_ADDRESS = "::1";
          ROCKET_PORT = 8222;
          SIGNUPS_ALLOWED = false;
          SMTP_FROM = "contact@hoppenr.xyz";
          SMTP_FROM_NAME = "Vaultwarden Service";
          SMTP_HOST = "127.0.0.1";
          SMTP_PORT = 25;
          SMTP_SSL = false;
        };
      };
    };

  sops = {
    secrets = {
      "cloudflare-account-tag".key = "cloudflare/account-tag";
      "cloudflare-api-token".key = "cloudflare/api-token";
      "cloudflare-tunnel-id".key = "cloudflare/tunnel-id";
      "cloudflare-tunnel-secret".key = "cloudflare/tunnel-secret";
      "postfix-token".key = "postfix/token";
    };
    templates = {
      "postfix-password-map" = {
        owner = config.services.postfix.user;
        inherit (config.services.postfix) group;
        content = ''
          [smtp.protonmail.ch]:587 contact@${domainName}:${config.sops.placeholder."postfix-token"}
        '';
      };
      "cloudflare-tunnel-config" = {
        content = ''
          {
            "AccountTag": "${config.sops.placeholder."cloudflare-account-tag"}",
            "TunnelSecret": "${config.sops.placeholder."cloudflare-tunnel-secret"}",
            "TunnelID": "${config.sops.placeholder."cloudflare-tunnel-id"}"
          }
        '';
      };
      "caddy-dns-config" = {
        owner = config.users.users.caddy.name;
        inherit (config.users.users.caddy) group;
        content = ''
          tls {
            dns cloudflare ${config.sops.placeholder.cloudflare-api-token}
          }
        '';
      };
    };
  };

  systemd.services = {
    vaultwarden = {
      after = [ "postgresql.service" ];
      requires = [ "postgresql.service" ];
    };
  };

  # users.users.${mainUser}.extraGroups = [
  #   "dialout"
  #   "tty"
  # ];

  virtualisation = {
    podman.autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # TODO: move to module for mysql ?
  #       still needed after moving to nftables?
  networking = {
    firewall.extraInputRules = ''
      iifname "podman0" tcp dport 3306 accept
    '';
  };
}
