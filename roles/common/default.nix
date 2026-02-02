{
  config,
  identities,
  inputs,
  lib,
  mainUser,
  pkgs,
  topology,
  ...
}:
let
  machine = topology.${config.networking.hostName};
in
{

  imports = [
    ./greetd.nix

    inputs.home-manager.nixosModules.home-manager
    # inputs.run0-sudo-shim.nixosModules.default
    inputs.sops-nix.nixosModules.sops
  ];

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 5;
      };
      efi.canTouchEfiVariables = true;
    };
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

  environment = {
    shellAliases = {
      l = null;
      ll = "ls --almost-all -lh";
      ls = "ls --color=auto";
    };
    systemPackages =
      (builtins.attrValues {
        inherit (pkgs)
          gcc
          git
          neovim-unwrapped
          sops
          yubikey-manager
          ;
      })
      ++ [
        (pkgs.symlinkJoin {
          name = "neovim-system-aliases";
          paths = [ pkgs.neovim-unwrapped ];
          postBuild = ''
            ln -s ${lib.getExe pkgs.neovim-unwrapped} $out/bin/vi
            ln -s ${lib.getExe pkgs.neovim-unwrapped} $out/bin/vim
          '';
        })
      ];
  };

  fonts.packages = builtins.attrValues {
    inherit (pkgs.nerd-fonts)
      jetbrains-mono
      ;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs; };
    users = {
      ${mainUser} = ../../home/common.nix;
    };
  };

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_TIME = "sv_SE.UTF-8";
      LC_MONETARY = "sv_SE.UTF-8";
      LC_MEASUREMENT = "sv_SE.UTF-8";
      LC_PAPER = "sv_SE.UTF-8";
      LC_NUMERIC = "sv_SE.UTF-8";
    };
  };

  networking = {
    defaultGateway = {
      address = "192.168.0.1";
      interface = "lan0";
    };
    nftables.enable = true;
    hosts = lib.mapAttrs' (hostName: hostData: lib.nameValuePair hostData.ipv4 [ hostName ]) (
      lib.filterAttrs (hostName: hostData: hostName != config.networking.hostName) topology
    );
    interfaces.lan0 = {
      ipv4.addresses = [
        {
          address = machine.ipv4;
          prefixLength = 24;
        }
      ];
      ipv6.addresses = [
        {
          address = machine.ipv6;
          prefixLength = 64;
        }
      ];
      useDHCP = false;
    };
    resolvconf.enable = false;
    useNetworkd = true;
  };

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
    };
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      allowed-users = [ "@wheel" ];
      trusted-users = [ "@wheel" ];
    };
  };

  programs = {
    ssh = {
      knownHosts = lib.mapAttrs (hostName: hostData: {
        hostNames = [
          hostName
          hostData.ipv4
        ];
        publicKey = hostData.publicKey;
      }) (lib.filterAttrs (hostName: hostData: hostData ? publicKey) topology);
      extraConfig =
        let
          mainuserHome = config.home-manager.users.${mainUser};
        in
        ''
          Match localuser ${mainUser}
            AddKeysToAgent yes
            IdentityFile ${mainuserHome.xdg.stateHome}/ssh/id_ed25519
            UserKnownHostsFile ${mainuserHome.xdg.stateHome}/ssh/known_hosts.d/%k
          Match localuser root
            IdentityFile /persist/etc/ssh/ssh_host_ed25519_key
        '';
    };
    zsh.enable = true;
  };

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    # created by services.openssh.hostKeys
    age.sshKeyPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
    secrets.user-password.neededForUsers = true;
  };

  security = {
    pam.u2f = {
      enable = true;
      settings = {
        userpresence = 1;
        cue = true;
      };
    };
    polkit = {
      enable = true;
    };
    # run0-sudo-shim.enable = true;
    # sudo.enable = false;
  };

  services = {
    pcscd.enable = true;
    resolved.enable = true;
    udev = {
      packages = builtins.attrValues {
        inherit (pkgs)
          yubikey-personalization
          ;
      };
    };
    zfs = {
      autoScrub = {
        enable = true;
        interval = "monthly";
      };
    };
  };

  systemd.services."trim-nix-profiles" = {
    description = "Trim nix profiles to keep last 5 generations";
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.nix}/bin/nix-env --profile /nix/var/nix/profiles/system --delete-generations +5
      ${pkgs.nix}/bin/nix-env --profile /etc/profiles/per-user/${mainUser} --delete-generations +5
      /run/current-system/bin/switch-to-configuration boot
    '';
    startAt = "weekly";
  };

  time.timeZone = "Europe/Stockholm";

  users = {
    mutableUsers = false;
    users = {
      ${mainUser} = {
        extraGroups = [
          "video"
          "input"
          "disk"
          "wheel"
        ];
        hashedPasswordFile = config.sops.secrets.user-password.path;
        isNormalUser = true;
        shell = pkgs.zsh;
        openssh.authorizedKeys.keys = lib.concatMap (
          name: identities.people.${name}.publicKeys
        ) machine.admins;
      };
      "root" = {
        hashedPassword = null;
      };
    };
  };
}
