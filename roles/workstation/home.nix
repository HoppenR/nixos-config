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
  ];
  xdg = {
    enable = true;
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/*" = [ "nvim.desktop" ];
        "inode/directory" = [ "kitty-open.desktop" ];
      };
    };
  };

  home.packages = builtins.attrValues {
    inherit (pkgs)
      discord
      fd
      jq
      libnotify
      ripgrep
      tree-sitter
      unzip
      wget
      wl-clipboard
      ;
  };

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    settings = {
      "$mod_apps" = "MOD3";
      "$mod_move" = "SUPER";
      "$mod_hypr" = "MOD5";
      "$menu_opts" = "--insensitive --match=multi-contains";
      "$run_menu" = "wofi --show=run $menu_opts";
      "$drun_menu" = "wofi --show=drun $menu_opts";
      bind = [
        "$mod_apps, RETURN, exec, kitty"
        "$mod_apps, w, exec, firefox"
        "$mod_apps, q, exec, $run_menu"
        "$mod_apps, d, exec, $drun_menu"
        "$mod_apps, f, exec, ${pkgs.hyprshot}/bin/hyprshot --mode region"
        "$mod_move, h, movefocus, l"
        "$mod_move, j, movefocus, d"
        "$mod_move, k, movefocus, u"
        "$mod_move, l, movefocus, r"
        "$mod_move, q, workspace, 1"
        "$mod_move, w, workspace, 2"
        "$mod_move, e, workspace, 3"
        "$mod_move, r, workspace, 4"
        "$mod_move, t, workspace, 5"
        "$mod_move, y, workspace, 6"
        "$mod_move, u, workspace, 7"
        "$mod_move, i, workspace, 8"
        "$mod_move, o, workspace, 9"
      ];
      device = {
        name = "at-translated-set-2-keyboard";
        repeat_delay = 200;
        repeat_rate = 25;
      };
      input = {
        kb_layout = "se";
        kb_file = "${pkgs.writeText "hyprland.xkb" /* xkb */ ''
          xkb_keymap {
            xkb_keycodes { include "evdev+aliases(qwerty)" };
            xkb_types { include "complete" };
            xkb_compat { include "complete" };
            xkb_symbols {
              include "pc+se+ru:2+inet(evdev)"
              replace key <PRSC> { [ ISO_Level5_Shift ] };
              replace key <CAPS> {
                type = "TWO_LEVEL",
                symbols[Group1] = [ ISO_Next_Group, Caps_Lock ]
              };
            };
          };
        ''}";
      };
      monitor = [
        "Virtual-1, 1920x1080@60.00400, 0x0, 1"
      ];
    };
    xwayland.enable = true;
  };

  programs = {
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
    };
    firefox = {
      enable = true;
      languagePacks = [
        "en-US"
        "sv-SE"
      ];
    };
    git = {
      enable = true;
      settings = {
        user = {
          name = "Christoffer Lundell";
          email = "christofferlundell@protonmail.com";
        };
        safe.directory = "/persist/nixos";
        init.defaultBranch = "main";
      };
    };
    gpg = {
      enable = true;
      homedir = "${config.xdg.stateHome}/gnupg";
      scdaemonSettings = {
        disable-ccid = true;
        pcsc-shared = true;
        deny-admin = true;
      };
      publicKeys = [
        {
          source = ../../keys/pgp_pub.asc;
          trust = 5;
        }
      ];
    };
    hyprlock = {
      enable = true;
      settings = {
        general = {
          hide_cursor = true;
          ignore_empty_input = true;
        };

        background = [
          {
            path = "~/Pictures/backgrounds/storm-blossom.png";
            blur_passes = 3;
            blur_size = 8;
          }
        ];
        input-field = [
          {
            monitor = "";
            size = "200, 50";
            position = "0, -80";
            dots_center = true;
            fade_on_empty = false;
            font_color = "rgb(202, 211, 245)";
            inner_color = "rgb(91, 96, 120)";
            outer_color = "rgb(24, 25, 38)";
            outline_thickness = 5;
            # placeholder_text = "<span foreground=\"##cad3f5\">Password...</sp an>";
            shadow_passes = 2;
          }
        ];
      };
    };
    kitty = {
      enable = true;
      shellIntegration = {
        enableZshIntegration = true;
      };
      settings = {
        font_family = "monospace";
        font_size = 15;
        disable_ligatures = "cursor";
        scrollback_lines = 5000;
        enable_audio_bell = false;
        visual_bell_duration = 0.5;
        visual_bell_color = "black";
        window_alert_on_bell = true;
        remember_window_size = false;
        tab_bar_edge = "top";
        tab_bar_style = "powerline";
        tab_bar_align = "left";
        tab_bar_min_tabs = 1;
        tab_title_template = "{index}: {tab.active_exe}";
        background_opacity = 0.85;
        "map ctrl+alt+1" = "first_window";
        "map ctrl+alt+2" = "second_window";
        "map ctrl+alt+3" = "third_window";
        "map kitty_mod+t" = "new_tab_with_cwd";
        "map kitty_mod+y" = "new_tab";
        "map alt+1" = "goto_tab 1";
        "map alt+2" = "goto_tab 2";
        "map alt+3" = "goto_tab 3";
        "map alt+4" = "goto_tab 4";
        cursor_trail = 1;
        cursor_trail_decay = "0.1 0.1";
        cursor_trail_start_threshold = 2;
      };
    };
    neovim = {
      enable = true;
      extraLuaConfig = /* lua */ ''
        vim.cmd.filetype({ args = { 'plugin', 'indent', 'on' } })
        vim.cmd.syntax('on')
        vim.o.termguicolors = true
        vim.cmd.colorscheme('habamax')
        vim.g.loaded_netrw = 1
        vim.g.loaded_netrwPlugin = 1
        vim.g.mapleader = ' '

        require('rocks-nvim')

        vim.o.autochdir = true
        vim.o.cursorline = true
        vim.o.expandtab = true
        vim.o.fileignorecase = true
        vim.o.ignorecase = true
        vim.o.list = true
        vim.o.number = true
        vim.o.relativenumber = true
        vim.o.ruler = false
        vim.o.smartcase = true
        vim.o.splitbelow = true
        vim.o.splitright = true
        vim.o.title = true
        vim.o.undofile = true
        vim.o.wrap = false
        vim.o.virtualedit = 'block'

        vim.o.clipboard = 'unnamed'
        vim.o.colorcolumn = '80'
        vim.o.conceallevel = 2
        vim.o.foldmethod = 'marker'
        vim.o.laststatus = 3
        vim.o.pumblend = 0
        vim.o.shiftwidth = 0
        vim.o.signcolumn = 'no'
        vim.o.shortmess = 'AFOTWiost'
        vim.o.statusline = table.concat({
          ' ',
          '%F', -- Long filename
          '%m', -- Changed file
          '%=', -- Separate sections
          ' 󱑜 %{&fileencoding} ',
          '  %{&filetype} ',
          '  %{&fileformat} ',
          ' %l %v ',
          ' %p%% ',
        })
        vim.o.tabstop = 4
        vim.o.textwidth = 80
        vim.o.timeoutlen = 500
        vim.o.titlestring = '%F - NVIM'
        vim.o.ttimeoutlen = 50
        vim.o.updatetime = 500
        vim.o.winbar = '%=%f %r%m%='
        vim.o.winborder = 'rounded'
        vim.o.winblend = 0

        vim.opt.cinoptions = { ':0', 'g0', '(0', 'W4', 'l1' }
        vim.opt.completeopt = { 'menuone', 'noinsert', 'popup' }
        vim.opt.foldmarker = { '{{{', '}}}' }
        vim.opt.listchars = { extends = '▸', nbsp = '◇', tab = '│ ', trail = '∘', leadmultispace = '│   ' }
        vim.opt.matchpairs = { '(:)', '{:}', '[:]', '<:>', '«:»' }

        vim.diagnostic.config({
          virtual_text = true,
          virtual_lines = false,
          signs = false,
          update_in_insert = true,
        })
        local AutoSetIndentChars = vim.api.nvim_create_augroup('AutoSetIndentChars', { clear = true })
        local function set_lead_indent_chars()
          vim.opt_local.listchars:append({
            leadmultispace = '│' .. string.rep(' ', vim.fn.shiftwidth() - 1)
          })
        end
        vim.api.nvim_create_autocmd('OptionSet', {
          pattern = { 'shiftwidth' },
          group = AutoSetIndentChars,
          callback = set_lead_indent_chars,
        })
        vim.api.nvim_create_autocmd('BufWinEnter', {
          pattern = '*',
          group = AutoSetIndentChars,
          callback = set_lead_indent_chars,
        })
      '';
      defaultEditor = true;
      plugins = builtins.attrValues {
        inherit (pkgs.vimPlugins)
          rocks-nvim
          ;
      };
      viAlias = true;
      vimAlias = true;
    };
    nix-index-database.comma.enable = true;
    obs-studio = {
      enable = true;
    };
    waybar = {
      enable = true;
      systemd.enable = true;
      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          modules-left = [
            "hyprland/workspaces"
            "hyprland/submap"
            "cpu"
          ];
          modules-center = [ "clock" ];
          modules-right = [
            "bluetooth"
            "network"
            "pulseaudio"
            "backlight"
            "battery"
          ];
          "cpu" = {
            format = "  {icon0} {icon1} {icon2} {icon3} {usage:>2}%";
            format-icons = [
              "▁"
              "▂"
              "▃"
              "▄"
              "▅"
              "▆"
              "▇"
              "█"
            ];
          };
          "pulseaudio" = {
            format = "{icon} {volume}%";
            format-muted = "";
            format-icons = {
              default = [
                ""
                ""
                " "
              ];
            };
          };
        };
      };
      style = /* css */ ''
        * {
          background: transparent;
          font-size: 14px;
        }
        #workspaces,
        #cpu,
        #clock {
          background-color: #1a1b26;
          padding: 0.3rem 0.7rem;
          margin: 5px 0px;
          border-radius: 6px;
          box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
          min-width: 0;
          border: none;
          transition: background-color 0.2s ease-in-out, color 0.2s ease-in-out;
        }
        #workspaces {
          padding: 2px;
          margin-left: 7px;
          margin-right: 5px;
        }
        #workspaces > button {
          color: #babbf1;
          border-radius: 5px;
          padding: 0.3rem 0.6rem;
          background: transparent;
          transition: all 0.2s ease-in-out;
          border: none;
          outline: none;
          box-shadow: none;
        }
        #workspaces > button:hover {
          background-image: none;
          text-shadow: none;
        }
        #workspaces button.active {
          background-color: rgba(153, 209, 219, 0.1);
        }
        #bluetooth,
        #pulseaudio,
        #backlight,
        #network,
        #battery {
          background-color: #1a1b26;
          padding: 0.3rem 0.7rem;
          margin: 5px 0px;
          border-radius: 0;
          box-shadow: none;
          min-width: 0;
          border: none;
          transition: background-color 0.2s ease-in-out, color 0.2s ease-in-out;
        }
        #bluetooth {
          margin-left: 0px;
          border-top-left-radius: 6px;
          border-bottom-left-radius: 6px;
        }
        #battery {
          border-top-right-radius: 6px;
          border-bottom-right-radius: 6px;
          margin-right: 7px;
        }
        #cpu,
        #pulseaudio,
        #backlight,
        #network {
          color: #c6d0f5;
        }
        #battery,
        #battery.charging,
        #bluetooth.connected,
        #clock {
          color: #99d1db;
        }
        #clock {
          font-weight: 600;
        }
        #network.disconnected {
          color: #e78284;
        }
        #bluetooth {
          color: #888888;
          font-size: 16px;
        }
        #bluetooth.on {
          color: #2196f3;
        }
        #battery.warning:not(.charging) {
          color: #e78284;
        }
      '';
    };
    zsh = {
      enable = true;
      enableCompletion = true;
      defaultKeymap = "viins";
      dirHashes = {
        nix = "/persist/nixos";
        personal = "${config.home.homeDirectory}/projects/personal";
      };
      dotDir = "${config.xdg.configHome}/zsh";
      history = {
        append = true;
        expireDuplicatesFirst = true;
        findNoDups = true;
        path = "${config.xdg.stateHome}/zsh/history";
      };
      initContent = lib.mkMerge [
        (lib.mkOrder 520 /* bash */ ''
          prompt off
          autoload -Uz add-zsh-hook vcs_info
          add-zsh-hook precmd vcs_info
        '')
        (lib.mkAfter /* bash */ ''
          setopt    AUTO_PUSHD
          setopt no_CASE_GLOB
          setopt    CHASE_LINKS
          setopt    EXTENDED_GLOB
          setopt    HIST_EXPIRE_DUPS_FIRST
          setopt    HIST_FIND_NO_DUPS
          setopt    HIST_VERIFY
          setopt no_NO_MATCH
          setopt    MENU_COMPLETE
          setopt    PROMPT_SUBST
          setopt    SHARE_HISTORY
          stty -ixoff
          stty -ixon
          tabs -4

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
          zstyle ':vcs_info:git:**' stagedstr '+'
          zstyle ':vcs_info:git:**' unstagedstr '*'

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
          bindkey -M vicmd      '^[[F' end-of-line
          bindkey -M vicmd      '^[[H' beginning-of-line
          bindkey -M vicmd      'z='   spell-word
          bindkey -M viins      '^?'   backward-delete-char
          bindkey -M viins      '^B'   beginning-of-line
          bindkey -M viins      '^E'   end-of-line
          bindkey -M viins      '^W'   backward-kill-word
          bindkey -M viins      '^[[A' history-beginning-search-backward
          bindkey -M viins      '^[[B' history-beginning-search-forward
          bindkey -M viins      '^[[F' end-of-line
          bindkey -M viins      '^[[H' beginning-of-line
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

          function _assert_zle_context() {
            if [[ -z "$WIDGET" ]]; then
              print -u2 "TODO expected to run in a zle context"
              return 1
            fi
          }
          function _vi-yank-arg() {
            NUMERIC=1 zle .vi-add-next
            zle .insert-last-word
          }
          function _closest-history-match-accept() {
              _assert_zle_context || return
              zle history-beginning-search-backward
              zle end-of-line
          }

          function _in_nix_shell() {
            if (( ''${+IN_NIX_SHELL} )); then
              echo "(nixshell:$IN_NIX_SHELL)"
            fi
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
        WORDCHARS = "*?[]~=&;!#$%^(){}<>";
        KEYTIMEOUT = 1;
        PS1 = "\\$(_in_nix_shell)[%n@%m %F{2}%4(c:…/:)%3c%f\\$vcs_info_msg_0_]%F{2}%(?.$.?)%f ";
        RPS1 = "%(?..%F{1}%?%f)";
        zle_highlight = [ "region:bg=6,fg=0" ];
      };
      shellAliases = {
        edit-var = "vared -i edit-command-line";
        ssh = "kitty +kitten ssh";
      };
      syntaxHighlighting.enable = true;
    };
  };

  services = {
    gpg-agent = {
      enable = true;
      enableSshSupport = true;
      pinentry.package = pkgs.pinentry-curses; # FIXME
    };
    hypridle = {
      enable = true;
      settings = {
        general = {
          after_sleep_cmd = "hyprctl dispatch dpms on";
          ignore_dbus_inhibit = false;
          lock_cmd = "${pkgs.hyprlock}/bin/hyprlock";
        };
        listener = [
          {
            timeout = 900;
            on-timeout = "${pkgs.hyprlock}/bin/hyprlock";
          }
          {
            timeout = 1200;
            on-timeout = "${pkgs.hyprland}/bin/hyprctl dispatch dpms off";
            on-resume = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
          }
        ];
      };
    };
    hyprpaper = {
      enable = true;
      settings = {
        ipc = "on";
        splash = true;
        splash_offset = 2.0;
        preload = [
          "${config.home.homeDirectory}/Pictures/backgrounds/storm-blossom.png"
        ];
        wallpaper = [
          ",${config.home.homeDirectory}/Pictures/backgrounds/storm-blossom.png"
        ];
      };
    };
  };

  systemd.user.services = {
    hyprnotify = {
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.hyprnotify}/bin/hyprnotify";
        Restart = "always";
        RestartSec = 10;
      };
      Unit = {
        After = [ "graphical-session.target" ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
        Description = "`hyprctl notify` daemon for dbus clients";
        PartOf = "graphical-session.target";
      };
    };
  };

  xdg.configFile = {
    "nvim/lua/nix-deps.lua" =
      let
        luaInterpreter = config.programs.neovim.package.lua;
      in
      {
        enable = true;
        text = /* lua */ ''
          local M = {}
          M.gcc_path = "${pkgs.gcc}/bin/gcc"
          M.lua_interpreter = "${luaInterpreter}"
          M.luarocks_executable = "${luaInterpreter.pkgs.luarocks_bootstrap}/bin/luarocks"
          return M
        '';
      };

    "nvim/luarocks-config-generated.lua" =
      let
        luaInterpreter = config.programs.neovim.package.lua;
        luarocksStore = luaInterpreter.pkgs.luarocks;
        luacurlPkg = luaInterpreter.pkgs.lua-curl;
        luarocksInitialConfigAttr =
          pkgs.lua.pkgs.luaLib.generateLuarocksConfig { externalDeps = [ pkgs.curl.dev ]; }
          // {
            lua_version = "5.1";
          };
        luarocksConfigAttr = lib.recursiveUpdate luarocksInitialConfigAttr {
          rocks_trees = [
            {
              name = "rocks.nvim";
              root = "${config.xdg.dataHome}/nvim/rocks";
            }
            {
              name = "rocks-generated.nvim";
              root = "${luarocksStore}";
            }
            {
              name = "lua-curl";
              root = "${luacurlPkg}";
            }
            {
              name = "sqlite.lua";
              root = "${luaInterpreter.pkgs.sqlite}";
            }
          ];
          variables = {
            # MYSQL_INCDIR = "${libmysqlclient.dev}/include/mysql";
            # MYSQL_LIBDIR = "${libmysqlclient}/lib/mysql";
          };
        };
        luarocksConfigStr = lib.generators.toLua { asBindings = false; } luarocksConfigAttr;
      in
      {
        enable = true;
        text = "return ${luarocksConfigStr}";
      };

    "nvim/lua/rocks-nvim.lua".text = /* lua */ ''
      local nix_deps = require("nix-deps")
      local luarocks_config_filename = vim.fn.stdpath('config') .. '/luarocks-config-generated.lua'
      local luarocks_config_fn = assert(loadfile(luarocks_config_filename))
      local rocks_config = {
        luarocks_binary = nix_deps.luarocks_executable,
        luarocks_config = luarocks_config_fn(),
        rocks_path = vim.fn.stdpath("data") .. "/rocks",
      }
      vim.g.rocks_nvim = rocks_config
    '';
    "nvim/ftplugin/dart.lua".text = /* lua */ ''
      vim.opt_local.shiftwidth = 2
    '';
    "nvim/ftplugin/go.lua".text = /* lua */ ''
      vim.opt_local.expandtab = false
      vim.opt_local.tabstop = 8
      vim.cmd.compiler('go')
    '';
    "nvim/ftplugin/nix.lua".text = /* lua */ ''
      vim.opt_local.shiftwidth = 2
      vim.opt_local.iskeyword:append('-')
    '';
    "nvim/ftplugin/ocaml.lua".text = /* lua */ ''
      vim.opt_local.shiftwidth = 2
    '';
    "nvim/ftplugin/zsh.lua".text = /* lua */ ''
      vim.opt_local.iskeyword:append('-')
    '';
    "nvim/lua/plugins/fidget-nvim.lua".text = /* lua */ ''
      require('fidget').setup({
        integration = {
          ['nvim-tree'] = { enable = false },
          ['xcodebuild-nvim'] = { enable = false },
        },
        notification = {
          override_vim_notify = true,
          view = { stack_upwards = false },
          window = { border = vim.o.winborder },
        },
      })
    '';
    "nvim/lua/plugins/flutter-tools-nvim.lua".text = /* lua */ ''
      FlutterTools = require('flutter-tools')
      FlutterTools.setup({})
    '';
    "nvim/lua/plugins/oil-nvim.lua".text = /* lua */ ''
      Oil = require('oil')
      vim.keymap.set('n', '<M-e>', Oil.open)
      Oil.setup({
        default_file_explorer = true,
        columns = {
          'icon',
          'permissions',
          'size',
          'mtime',
        },
      })
    '';
    "nvim/lua/plugins/telescope.lua".text = /* lua */ ''
      Telescope = require('telescope')
      Actions = require('telescope.actions')
      Builtin = require('telescope.builtin')
      vim.keymap.set('n', '<leader><leader>', Builtin.builtin)
      vim.keymap.set('n', '<leader>b', Builtin.buffers)
      vim.keymap.set('n', '<leader>c', Builtin.resume)
      vim.keymap.set('n', '<leader>f', Builtin.find_files)
      vim.keymap.set('n', '<leader>g', Builtin.live_grep)
      vim.keymap.set('n', '<leader>i', Builtin.lsp_implementations)
      vim.keymap.set('n', '<leader>l', Builtin.diagnostics)
      vim.keymap.set('n', '<leader>o', Builtin.oldfiles)
      vim.keymap.set('n', '<leader>r', Builtin.lsp_references)
      vim.keymap.set('n', '<leader>s', Builtin.lsp_document_symbols)
      vim.keymap.set('n', '<leader>t', Builtin.current_buffer_fuzzy_find)
      vim.keymap.set('n', '<leader>u', Telescope.extensions.undo.undo)
      vim.keymap.set('n', '<leader>v', Builtin.git_files)
      Telescope.setup({
        defaults = {
          scroll_strategy = 'limit',
          mappings = {
            n = {
              ['<C-d>'] = Actions.results_scrolling_down,
              ['<C-u>'] = Actions.results_scrolling_up,
              ['<Esc>'] = false,
              ['q'] = Actions.close,
            },
            i = {
              ['<C-b>'] = Actions.preview_scrolling_up,
              ['<C-d>'] = Actions.close,
              ['<C-f>'] = Actions.preview_scrolling_down,
              ['<C-u>'] = false,
            },
          },
        },
        pickers = {
          buffers = {
            mappings = {
              n = {
                ['dd'] = Actions.delete_buffer,
              },
            },
          },
        },
      })
    '';
    "nvim/plugin/lsp.lua".text = /* lua */ ''
      local servers = {
        -- 'clangd',        -- C/C++ language server
        -- 'dartls',        -- Dart langage server (Enabled via flutter-tools!)
        -- 'gopls',         -- Go language server
        -- 'hls',           -- Haskell language server
        'lua_ls',        -- Lua language server
        'nixd',          -- Nix language server
        -- 'pylsp',         -- Python language server
        -- 'rust_analyzer', -- Rust language server
        -- 'ts_ls',         -- Typescript language server
      }
      for _, server in ipairs(servers) do
        vim.lsp.enable(server)
      end

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client.server_capabilities.inlayHintProvider then
            vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
          end
        end,
      })
      local LspAutoTrigger = vim.api.nvim_create_augroup('LspAutoTrigger', { clear = true })
      vim.api.nvim_create_autocmd('LspAttach', {
        group = LspAutoTrigger,
        callback = function(ev)
          local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
          if client:supports_method('textDocument/completion', ev.buf) then
            local all = {}
            for code = 32, 126 do
              table.insert(all, string.char(code))
            end
            local excludes = { ' ', '(', ')', ';', '<', '>', '[', ']', '{', '}', ':' }
            local chars = vim.tbl_filter(
              function(ch)
                return not vim.tbl_contains(excludes, ch)
              end,
              all
            )
            client.server_capabilities.completionProvider.triggerCharacters = chars
            vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
          end
        end
      })

      local function default_lsp_binds(event)
        vim.keymap.set('i', '<C-Space>', vim.lsp.completion.get, { buffer = event.buf })
        vim.keymap.set('n', '<F2>', vim.lsp.buf.rename, { buffer = event.buf })
        vim.keymap.set('n', '<F3>', vim.lsp.buf.format, { buffer = event.buf })
        vim.keymap.set('n', '<F4>', function()
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client.server_capabilities.inlayHintProvider then
            vim.lsp.inlay_hint.enable(
              not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }),
              { bufnr = event.buf }
            )
          end
        end, { buffer = event.buf })
        vim.keymap.set('n', '<M-d>', vim.lsp.buf.code_action, { buffer = event.buf })
        vim.keymap.set('n', '<M-n>', function() vim.diagnostic.jump({ count = 1, float = true }) end, { buffer = event.buf })
        vim.keymap.set('n', '<M-p>', function() vim.diagnostic.jump({ count = -1, float = true }) end, { buffer = event.buf })
        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { buffer = event.buf })
        vim.keymap.set({ 'i', 's', }, '<C-h>', function() vim.snippet.jump(-1) end, { buffer = event.buf })
        vim.keymap.set({ 'i', 's', }, '<C-l>', function() vim.snippet.jump(1) end, { buffer = event.buf })
      end
      local LspKeybinds = vim.api.nvim_create_augroup('LspKeybinds', { clear = true })
      vim.api.nvim_create_autocmd('LspAttach', {
        group = LspKeybinds,
        callback = default_lsp_binds,
      })

      local LspSettings = vim.api.nvim_create_augroup('LspSettings', {
        clear = true
      })
      vim.api.nvim_create_autocmd('LspAttach', {
        group = LspSettings,
        callback = function(event)
          vim.api.nvim_create_autocmd('CursorHold', {
            buffer = event.buf,
            callback = vim.lsp.buf.document_highlight,
          })
          vim.api.nvim_create_autocmd('CursorMoved', {
            buffer = event.buf,
            callback = vim.lsp.buf.clear_references,
          })
        end
      })
    '';
    "nvim/lsp/nixd.lua".text = /* lua */ ''
      return {
        cmd = { '${pkgs.nixd}/bin/nixd' },
        filetypes = { 'nix' },
        settings = {
          nixd = {
            nixpkgs = {
              expr = '(builtins.getFlake "${config.home.homeDirectory}/projects/nixos").inputs.nixpkgs',
            },
            formatting = {
              command = { '${pkgs.nixfmt-rfc-style}/bin/nixfmt' },
            },
            options = {
              nixos = {
                expr = '(builtins.getFlake "${config.home.homeDirectory}/projects/nixos").nixosConfigurations.nixvm.options',
              },
            },
          },
        },
      }
    '';
    "nvim/lsp/lua_ls.lua".text =
      let
        lua_ls = "${pkgs.lua-language-server}/bin/lua-language-server";
      in
      /* lua */ ''
        return {
          cmd = { '${lua_ls}' },
          filetypes = { 'lua' },
          settings = {
            Lua = {
              completion = { callSnippet = 'Replace' },
              hint = { enable = true },
              runtime = { version = 'LuaJIT' },
              workspace = {
                library = {
                  [vim.fn.expand("$VIMRUNTIME/lua")] = true,
                  [vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true,
                },
              },
            },
          },
        }
      '';
  };

  home.file = {
    "${config.xdg.configHome}/nvim/rocks.toml" = {
      source = config.lib.file.mkOutOfStoreSymlink "/persist/nixos/res/rocks.toml";
    };
    ".pki" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.stateHome}/pki";
    };
  };

  home.sessionVariables = {
    BROWSER = "firefox";
    CARGO_HOME = "${config.xdg.cacheHome}/cargo";
    FZF_ALT_C_COMMAND = "fd --strip-cwd-prefix --type directory";
    FZF_CTRL_R_OPTS = "--border=rounded";
    FZF_CTRL_T_COMMAND = "fd --strip-cwd-prefix --type file";
    LESS = "-FRX -x1,5";
    LESSHISTFILE = "${config.xdg.stateHome}/less/history";
    TERMINAL = "kitty";
  };

  home.stateVersion = "25.11";
  programs.home-manager.enable = true;
}
