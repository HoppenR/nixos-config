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
  roles = import ../../roles { inherit lib; };

  mainuserHome = config.home-manager.users.mainuser;
in
{
  _module.args = {
    inherit roles;
  };
  imports = [
    ../common/options.nix
    ../common/zrepl.nix
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
  ];

  environment = {
    shellAliases = {
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

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      boot.zfs.forceImportRoot = false;
    };
    zfs.extraPools = [ "holt" ];
    # kernelParams = [
    #   # 4GiB = 4 * 1024 * 1024 * 1024 = 4294967296 byte
    #   "zfs.zfs_arc_max=4294967296"
    #   # 2GiB = 2 * 1024 * 1024 * 1024 = 2147483600 byte
    #   "zfs.zfs_arc_min=2147483648"
    # ];
  };

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
    secrets.user-password.neededForUsers = true;
  };

  lab = {
    zrepl = {
      enable = true;
      type = "sink";
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

  services = {
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
    udev = {
      packages = builtins.attrValues {
        inherit (pkgs)
          yubikey-personalization
          ;
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

  networking = {
    hostId = "299a21e5";
    hostName = roles."${config.networking.role}".hostName;
    hosts = lib.mapAttrs' (_: host: lib.nameValuePair host.ipv4 [ host.hostName ]) (
      lib.filterAttrs (role: host: (host ? ipv4) && (role != config.networking.role)) roles
    );
    role = "storage";
    firewall.allowedTCPPorts = [ ];
    firewall.allowedUDPPorts = [ ];
    firewall.enable = true;

    defaultGateway = "192.168.0.1";
    interfaces.ens18 = {
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
    useDHCP = false;
  };

  system.stateVersion = "25.11"; # Did you read the comment?
}
