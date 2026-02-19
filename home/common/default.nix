{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    inputs.nix-index-database.homeModules.nix-index
    ./neovim.nix
  ];

  fonts.fontconfig.defaultFonts = {
    monospace = [ "JetBrainsMono Nerd Font" ];
  };

  home = {
    preferXdgDirectories = true;
    packages = builtins.attrValues {
      inherit (pkgs)
        fd
        jq
        ripgrep
        tree-sitter
        unzip
        wget
        ;

      inherit (pkgs.maple-mono // pkgs)
        NF
        cozette
        fira-code
        jetbrains-mono
        noto-fonts
        ;
    };
  };

  programs = {
    less = {
      enable = true;
      options = {
        RAW-CONTROL-CHARS = true;
        ignore-case = true;
        no-init = true;
        quit-if-one-screen = true;
        tabs = "1,5";
      };
    };
    btop = {
      enable = true;
      settings = {
        vim_keys = true;
        proc_filter_kernel = true;
      };
    };
    fzf = {
      enable = true;
      enableZshIntegration = true;
      changeDirWidgetCommand = "fd --type directory";
      colors = {
        "bg" = "#1a1b26";
        "bg+" = "#005f60";
        "fg" = "#c6d0f5";
        "fg+" = "#fff0e0";
        "hl" = "#ffffff";
        "hl+" = "#d8d9ff";
        "pointer" = "#c6d0f5";
      };
      defaultCommand = "fd --type file";
      fileWidgetCommand = "fd --type file";
      historyWidgetOptions = [ "--border=rounded" ];
    };
    git = {
      enable = true;
      signing = {
        key = "EB37A6ACFEC39658!";
        signByDefault = true;
      };
      settings = {
        init.defaultBranch = "main";
        user = {
          name = "Christoffer Lundell";
          email = "christofferlundell@protonmail.com";
        };
      };
    };
    gpg = {
      enable = true;
      homedir = "${config.xdg.stateHome}/gnupg";
      scdaemonSettings = {
        disable-ccid = true;
        # Disabling this enables the OpenPGP PIN cache, but creates resource contention for other commands
        pcsc-shared = false;
        deny-admin = true;
      };
      publicKeys = [
        {
          source = ../../keys/pgp_pub.asc;
          trust = 5;
        }
      ];
    };
    home-manager = {
      enable = true;
    };
    readline = {
      enable = true;
      bindings = {
        "\\C-b" = "beginning-of-line";
        "\\C-e" = "end-of-line";
        "\\C-l" = "clear-screen";
      };
      variables = {
        completion-ignore-case = true;
        editing-mode = "vi";
        expand-tilde = true;
        keymap = "vi-insert";
        keyseq-timeout = 50;
        show-all-if-ambiguous = true;
        show-mode-in-prompt = true;
        vi-cmd-mode-string = ''\1\e[0 q\2'';
        vi-ins-mode-string = ''\1\e[5 q\2'';
      };
    };
    nix-index.enable = true;
    nix-index-database.comma.enable = true;
    zsh = {
      enable = true;
      enableCompletion = true;
      defaultKeymap = "viins";
      dotDir = "${config.xdg.configHome}/zsh";
      history = {
        append = true;
        expireDuplicatesFirst = true;
        findNoDups = true;
        path = "${config.xdg.stateHome}/zsh/history";
      };
      initContent = lib.mkMerge [
        (lib.mkOrder 520 /* zsh */ ''
          prompt off
          autoload -Uz add-zsh-hook vcs_info
          add-zsh-hook precmd vcs_info
        '')
        (lib.mkAfter /* zsh */ ''
          setopt    AUTO_PUSHD
          setopt no_CASE_GLOB
          setopt    CHASE_LINKS
          setopt    EXTENDED_GLOB
          setopt    HIST_IGNORE_ALL_DUPS
          setopt    HIST_VERIFY
          setopt no_NO_MATCH
          setopt    MENU_COMPLETE
          setopt    PROMPT_SUBST
          setopt    SHARE_HISTORY
          setopt    TRANSIENT_RPROMPT
          stty -ixoff
          stty -ixon
          tabs -4

          zstyle ':completion:*' completer _expand_alias _complete _ignored
          zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
          zstyle ':completion:*' group-name ""
          zstyle ':completion:*' insert-unambiguous true
          zstyle ':completion:*' menu select=1 interactive
          zstyle ':completion:*' rehash true
          zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'
          zstyle ':completion:*' verbose true
          zstyle ':completion:*:descriptions' format '%F{green}-- %d --%f'
          zstyle ':completion:*:*:cd:*' ignore-parents false
          zstyle ':completion:*:*:cd:*' special-dirs true
          zstyle ':completion:*' matcher-list "''${_zshrc_matchers[@]}"

          zstyle ':vcs_info:*' enable git
          zstyle ':vcs_info:git:**' check-for-changes true
          zstyle ':vcs_info:git:**' get-revision true
          zstyle ':vcs_info:git:**' get-messages true
          zstyle ':vcs_info:git:**' formats '(%b%m%u%c)'
          zstyle ':vcs_info:git:**' actionformats '(%b|%a%m%u%c)'
          zstyle ':vcs_info:git:**' stagedstr '%F{2}+%f'
          zstyle ':vcs_info:git:**' unstagedstr '%F{1}*%f'
          zstyle ':vcs_info:git*+set-message:*' hooks git-aheadbehind

          zmodload zsh/complist
          bindkey -M command    '^[' send-break
          bindkey -M menuselect '^I' vi-forward-char
          bindkey -M menuselect '^M' .accept-line
          bindkey -M menuselect '^['   send-break
          bindkey -M menuselect '^e'   send-break
          bindkey -M menuselect '^h'   vi-backward-char
          bindkey -M menuselect '^j'   vi-down-line-or-history
          bindkey -M menuselect '^k'   vi-up-line-or-history
          bindkey -M menuselect '^l'   vi-forward-char
          bindkey -M menuselect '^n'   vi-down-line-or-history
          bindkey -M menuselect '^p'   vi-up-line-or-history
          bindkey -M menuselect '^y'   accept-line
          bindkey -M vicmd      '.'    vi-yank-arg
          bindkey -M vicmd      '^[OF' end-of-line
          bindkey -M vicmd      '^[OH' beginning-of-line
          bindkey -M vicmd      'z='   spell-word
          bindkey -M viins      '^?'   backward-delete-char
          bindkey -M viins      '^B'   beginning-of-line
          bindkey -M viins      '^E'   end-of-line
          bindkey -M viins      '^W'   backward-kill-word
          bindkey -M viins      '^[OA' history-beginning-search-backward
          bindkey -M viins      '^[OB' history-beginning-search-forward
          bindkey -M viins      '^[OF' end-of-line
          bindkey -M viins      '^[OH' beginning-of-line
          bindkey -M viins      '^a'   cd-show
          bindkey -M viins      '^g'   cdstack-menu
          bindkey -M viins      '§'    closest-history-match-accept
          bindkey -M visual     '¤'    edit-command-line

          if [[ "$aliases[run-help]" == 'man' ]]; then
              unalias run-help
          fi

          function take() {
            if [[ $1 =~ ^(https?|ftp).*\.(tar\.(gz|bz2|xz)|tgz)$ ]]; then
              takeurl "$1"
            elif [[ $1 =~ ^(https?|ftp).*\.(zip)$ ]]; then
              takezip "$1"
            elif [[ $1 =~ ^([A-Za-z0-9]\+@|https?|git|ssh|ftps?|rsync).*\.git/?$ ]]; then
              takegit "$1"
            else
              takedir "$@"
            fi
          }
          function takegit() {
            git clone "$1"
            cd "$(basename ''${1%%.git})"
          }
          function mkcd takedir() {
            mkdir -p $@ && cd ''${@:$#}
          }
          function takeurl() {
            local data thedir
            data="$(mktemp)"
            curl -L "$1" > "$data"
            tar xf "$data"
            thedir="$(tar tf "$data" | head -n 1)"
            rm "$data"
            cd "$thedir"
          }
          function takezip() {
            local data thedir
            data="$(mktemp)"
            curl -L "$1" > "$data"
            unzip "$data" -d "./"
            thedir="$(unzip -l "$data" | awk 'NR==4 {print $4}' | sed 's/\/.*//')"
            rm "$data"
            cd "$thedir"
          }

          function _vi-yank-arg() {
            NUMERIC=1 zle .vi-add-next
            zle .insert-last-word
          }
          function _closest-history-match-accept() {
              zle history-beginning-search-backward
              zle end-of-line
          }

          function _in_nix_shell() {
            if (( ''${+IN_NIX_SHELL} )); then
              echo "(nixshell:$IN_NIX_SHELL)"
            fi
          }
          function +vi-git-aheadbehind() {
            if ! git rev-parse --abbrev-ref @{u} >/dev/null 2>&1; then
              hook_com[misc]="[no-u]"
              return 0
            fi
            local -i ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null)
            local -i behind=$(git rev-list --count HEAD..@{u} 2>/dev/null)
            (( ahead > 0 )) && hook_com[misc]+="⇡$ahead"
            (( behind > 0 )) && hook_com[misc]+="⇣$behind"
          }

          zle -N edit-command-line
          zle -N closest-history-match-accept _closest-history-match-accept
          zle -N vi-yank-arg _vi-yank-arg
          autoload -Uz edit-command-line
          autoload -Uz run-help
        '')
      ];
      localVariables = {
        _zshrc_matchers = [
          "m:{a-z-}={A-Z_}" # Find exact matches first
          "m:{a-z-}={A-Z_} l:|=* r:|=*" # then try substring-matching
          "m:{a-z-}={A-Z_} r:|?=**" # then try fuzzy finding
        ];
        DISABLE_AUTO_TITLE = true;
        KEYTIMEOUT = 1;
        PROMPT = "\\$(_in_nix_shell)[%n@%m %F{2}%4(c:…/:)%3c%f\\$vcs_info_msg_0_]%F{2}%(?.$.?)%f ";
        RPROMPT = "%(?..%F{1}%?%f)";
        WORDCHARS = "*?[]~=&;!#$%^(){}<>";
        zle_highlight = [ "region:bg=14,fg=0" ];
      };
      shellAliases = {
        edit-var = "builtin vared -i edit-command-line";
      };
      syntaxHighlighting.enable = true;
    };
  };

  services = {
    gpg-agent = {
      enable = true;
      enableSshSupport = true;
      pinentry.package = lib.mkDefault pkgs.pinentry-curses;

      defaultCacheTtl = 900;
      defaultCacheTtlSsh = 900;
      maxCacheTtl = 7200;
      maxCacheTtlSsh = 7200;
    };
  };

  systemd.user = {
    tmpfiles.rules = [
      "d ${config.xdg.stateHome}/ssh 0700 ${config.home.username} users -"
      "d ${config.xdg.stateHome}/ssh/known_hosts.d 0700 ${config.home.username} users -"
    ];
  };

  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
    };
  };
}
