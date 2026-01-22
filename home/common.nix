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
    sessionVariables = {
      CARGO_HOME = "${config.xdg.dataHome}/cargo";
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
      changeDirWidgetOptions = [ "--strip-cwd-prefix" ];
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
      fileWidgetOptions = [ "--strip-cwd-prefix" ];
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
          source = ../keys/pgp_pub.asc;
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
    neovim = {
      enable = true;
      extraPackages = builtins.attrValues {
        inherit (pkgs)
          cargo
          ;
      };
      extraLuaConfig = /* lua */ ''
        vim.cmd.filetype({ args = { 'plugin', 'indent', 'on' } })
        vim.cmd.syntax('on')
        vim.o.termguicolors = true
        vim.api.nvim_set_hl(0, "WinBar", { link = "Normal" })
        vim.api.nvim_set_hl(0, "WinBarNC", { fg = "#707070", bg = "none" })
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
    configFile = {
      "nvim/rocks.toml".source = lib.mkDefault ../res/rocks.toml;
    };
    userDirs = {
      enable = true;
      createDirectories = true;
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
    "nvim/lua/plugins/oil-nvim.lua".text = /* lua */ ''
      Oil = require('oil')
      vim.keymap.set('n', '<M-e>', Oil.open)
      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "oil://*",
        callback = function()
          local dir = Oil.get_current_dir()
          if dir then
            vim.api.nvim_set_current_dir(dir)
          end
        end,
      })
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
        'lua_ls',
        'nixd',
      }
      for _, server in ipairs(servers) do
        vim.lsp.enable(server, true)
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
}
