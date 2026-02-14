{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../common
    ./booklore.nix
    ./endpoints
    ./joplin.nix
    ./vaultwarden.nix
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
      ${config.lab.mainUser} = import ../../home/logic.nix;
    };
  };

  lab = {
    booklore.enable = true;
    joplin.enable = true;
    openssh.enable = true;
    vaultwarden.enable = true;
    endpoints = {
      caddy.enable = true;
      cloudflared.enable = true;
      hosts = {
        "@".caddy.extraConfig = ''
          root * /replicated/web
          file_server browse
        '';
        "booklore".caddy.extraConfig = "reverse_proxy localhost:6060";
        "joplin".caddy.extraConfig = "reverse_proxy localhost:22300";
        "ssh" = {
          caddy.enable = false;
          ingress = "ssh://localhost:22";
        };
        "streams".caddy.extraConfig = "reverse_proxy localhost:${toString config.lab.streamsPort}";
        "vaultwarden".caddy.extraConfig = ''
          reverse_proxy localhost:${toString config.services.vaultwarden.config.ROCKET_PORT}
        '';
        "www".caddy.extraConfig = "redir https://${config.lab.domainName}{uri}";
      };
    };
    greetd = {
      enable = true;
      theme = "container=blue;window=black;border=magenta;greet=magenta;prompt=magenta;input=magenta;action=blue";
      useZshLogin = true;
    };
    streamsPort = 8181;
  };

  services = {
    pipewire.enable = false;
    postfix = {
      enable = true;
      settings.main = {
        inet_interfaces = "127.0.0.1, 10.88.0.1";
        mynetworks = [
          "127.0.0.0/8"
          "10.88.0.0/16"
        ];

        relayhost = [ "[smtp.protonmail.ch]:587" ];
        smtp_generic_maps = "inline:{ { root@${config.networking.hostName} = contact@${config.lab.domainName} } }";
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
        listen_addresses = lib.mkForce "127.0.0.1,10.88.0.1";
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
  };

  sops = {
    secrets = {
      "postfix-token".key = "postfix/token";
    };
    templates = {
      "postfix-password-map" = {
        owner = config.services.postfix.user;
        inherit (config.services.postfix) group;
        content = ''
          [smtp.protonmail.ch]:587 contact@${config.lab.domainName}:${config.sops.placeholder."postfix-token"}
        '';
      };
    };
  };

  # users.users.${config.lab.mainUser}.extraGroups = [
  #   "dialout"
  #   "tty"
  # ];

  virtualisation = {
    podman.autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # TODO: move to module for mysql/postgresql ?
  #       still needed after moving to nftables?
  #       3306 = mysql
  #       5432 = postgresql
  #       25   = smtp (by joplin)
  networking = {
    firewall.extraInputRules = ''
      iifname "podman0" tcp dport 3306 accept
      iifname "podman0" tcp dport 5432 accept
      iifname "podman0" tcp dport 25 accept
    '';
  };
}
