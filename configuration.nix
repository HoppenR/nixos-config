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
  allKeyData = import ./keys.nix;
  mainUser = "mainuser";
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
        glibc
        gcc
        sops
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
    # created by services.openssh.generateHostKeys
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    gnupg.sshKeyPaths = [ ];
    secrets = {
      user-password = {
        neededForUsers = true;
      };
      "streamserver-client-id".key = "streamserver/client-id";
      "streamserver-client-secret".key = "streamserver/client-secret";
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
        openssh.authorizedKeys.keys = lib.flatten (builtins.attrValues allKeyData);
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

  services = {
    pcscd.enable = true;
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = ''
            ${lib.getExe pkgs.tuigreet} \
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
      generateHostKeys = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        AllowAgentForwarding = false;
      };
    };
    pipewire.enable = false;
    udev = {
      packages = builtins.attrValues {
        inherit (pkgs)
          yubikey-personalization
          ;
      };
    };
  };

  security.pam.u2f = {
    enable = true;
    settings = {
      authfile = "/etc/u2f_keys";
      userpresence = 1;
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
        vaultwarden = {
          autoStart = true;
          image = "vaultwarden/server:latest";
          volumes = [ "/var/podman/vaultwarden-data:/data" ];
          ports = [ "8080:80" ];
          environment = {
            DOMAIN = "https://vaultwarden.hoppenr.xyz";
            SIGNUPS_ALLOWED = "false";
          };
        };
        streamserver = {
          autoStart = true;
          image = "ghcr.io/hoppenr/streamserver:latest";
          ports = [ "8181:8181" ];
          environmentFiles = [ config.sops.templates."streamserver-env".path ];
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ ];
  networking.firewall.allowedUDPPorts = [ ];
  networking.firewall.enable = true;

  system.stateVersion = "25.05"; # Did you read the comment?
}
