{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
let
  roles = import ../../roles { inherit lib; };

  mainuserHome = config.home-manager.users.christoffer;
in
{
  _module.args = {
    inherit roles;
  };
  imports = [
    ../common/greetd.nix
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
    colors = [
      "1d1f21"
      "dc322f"
      "859900"
      "b58900"
      "268bd2"
      "d33682"
      "2aa198"
      "eee8d5"
      "002b36"
      "cb4b16"
      "586e75"
      "657b83"
      "839496"
      "6c71c4"
      "93a1a1"
      "fdf6e3"
    ];
  };

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    # created by services.openssh.hostKeys
    age.sshKeyPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
    gnupg.sshKeyPaths = [ ];
    secrets.user-password.neededForUsers = true;
  };

  lab = {
    greetd = {
      enable = true;
    };
  };

  users = {
    mutableUsers = false;
    users = {
      christoffer = {
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
    hyprland.enable = true;
    ssh.extraConfig =
      let
        mainUserStatePath =
          if mainuserHome.xdg.enable then
            config.home-manager.users.christoffer.xdg.stateHome
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
    zsh.enable = true;
    steam.enable = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs; };
    users = {
      christoffer = import ./home.nix;
    };
  };

  hardware = {
    bluetooth = {
      enable = true;
      settings = {
        Policy = {
          AutoEnable = "true";
        };
      };
    };
    graphics.enable = true;
  };

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "discord"
      "steam"
      "steam-unwrapped"
    ];

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
    pipewire = {
      enable = true;
      pulse.enable = true;
      alsa.enable = true;
      jack.enable = true;
    };
    resolved.enable = true;
    pcscd.enable = true;
    fwupd = {
      enable = true;
    };
    tlp = {
      enable = true;
      settings = {
        SATA_LINKPWR_ON_BAT = "med_power_with_dipm";
        START_CHARGE_THRESH_BAT0 = 40;
        STOP_CHARGE_THRESH_BAT0 = 70;
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      };
    };
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

  networking = {
    useNetworkd = true;
    hostId = "007f0200";
    hostName = roles."${config.networking.role}".hostName;
    hosts = lib.mapAttrs' (_: host: lib.nameValuePair host.ipv4 [ host.hostName ]) (
      lib.filterAttrs (role: host: (host ? ipv4) && (role != config.networking.role)) roles
    );
    role = "workstation";

    firewall = {
      # Syncthing needs TCP/UDP 2200 and UDP 21027
      allowedTCPPorts = [
        22000
      ];
      allowedUDPPorts = [
        22000
        21027
      ];
    };
    firewall.enable = true;

    defaultGateway = {
      address = "192.168.0.1";
      interface = "lan0";
    };
    bonds = {
      lan0 = {
        interfaces = [
          "dock-lan"
          "laptop-lan"
        ];
        driverOptions = {
          miimon = "100";
          mode = "active-backup";
          primary = "dock-lan";
        };
      };
    };

    interfaces = {
      lan0 = {
        ipv4.addresses = [
          {
            address = roles."${config.networking.role}".ipv4;
            prefixLength = 24;
          }
        ];
        ipv6.addresses = [
          {
            address = roles."${config.networking.role}".ipv6;
            prefixLength = 64;
          }
        ];
        useDHCP = false;
      };
    };
    resolvconf.enable = false;
    useDHCP = false;

    wireless.iwd = {
      enable = true;
      settings = {
        General = {
          EnableNetworkConfiguration = true;
        };
        Network = {
          NameResolvingService = "systemd";
        };
      };
    };
  };

  systemd.network = {
    links = {
      "20-dock-lan" = {
        matchConfig.MACAddress = "84:ba:59:74:c0:bc";
        linkConfig.Name = "dock-lan";
      };
      "20-laptop-lan" = {
        matchConfig.MACAddress = "74:5d:22:39:03:cf";
        linkConfig.Name = "laptop-lan";
      };
      "20-laptop-wifi" = {
        matchConfig.MACAddress = "04:7b:cb:c1:96:22";
        linkConfig.Name = "laptop-wifi";
      };
    };
  };

  system.stateVersion = "25.11"; # Did you read the comment?
}
