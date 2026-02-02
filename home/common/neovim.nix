{
  lib,
  pkgs,
  ...
}:
{
  config = {
    programs = {
      neovim = {
        enable = true;
        extraPackages = builtins.attrValues {
          inherit (pkgs)
            cargo
            ;
        };
        initLua = /* lua */ ''
          vim.cmd.filetype({ args = { 'plugin', 'indent', 'on' } })
          vim.cmd.syntax('on')
          vim.o.termguicolors = true
          vim.api.nvim_set_hl(0, 'WinBar', { link = 'Normal' })
          vim.api.nvim_set_hl(0, 'WinBarNC', { fg = '#707070', bg = 'none' })
          vim.g.loaded_netrw = 1
          vim.g.loaded_netrwPlugin = 1
          vim.g.mapleader = ' '

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
        plugins = [
          {
            plugin = pkgs.vimPlugins.fidget-nvim;
            type = "lua";
            config = /* lua */ ''
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
          }
          {
            plugin = pkgs.vimPlugins.oil-nvim;
            type = "lua";
            config = /* lua */ ''
              Oil = require('oil')
              vim.keymap.set('n', '<M-e>', Oil.open)
              vim.api.nvim_create_autocmd('BufEnter', {
                pattern = 'oil://*',
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
          }
          {
            plugin = pkgs.vimPlugins.telescope-nvim;
            type = "lua";
            config = /* lua */ ''
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
          }
          {
            plugin = pkgs.vimPlugins.telescope-undo-nvim;
            type = "lua";
            config = /* lua */ ''
              Telescope = require('telescope')
              vim.keymap.set('n', '<leader>u', Telescope.extensions.undo.undo)
            '';
          }
        ]
        ++ [
          (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
            p.asm
            p.awk
            p.bash
            p.cmake
            p.commonlisp
            p.cpp
            p.css
            p.dart
            p.desktop
            p.diff
            p.dockerfile
            p.git_config
            p.git_rebase
            p.gitcommit
            p.gitignore
            p.go
            p.gomod
            p.gosum
            p.gpg
            p.haskell
            p.html
            p.hyprlang
            p.ini
            p.java
            p.javascript
            p.json
            p.json5
            p.latex
            p.lua
            p.make
            p.nginx
            p.nix
            p.ocaml
            p.passwd
            p.perl
            p.python
            p.readline
            p.rst
            p.rust
            p.sql
            p.ssh_config
            p.toml
            p.typescript
            p.xml
            p.yaml
            p.zsh
          ]))
        ];
        viAlias = true;
        vimAlias = true;
      };
    };
    xdg = {
      configFile = {
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

        "nvim/lsp/nixd.lua".text = /* lua */ ''
          return {
            cmd = { '${lib.getExe pkgs.nixd}' },
            filetypes = { 'nix' },
            settings = {
              nixd = {
                nixpkgs = {
                  expr = '(builtins.getFlake "/persist/nixos").inputs.nixpkgs',
                },
                formatting = {
                  command = { '${lib.getExe pkgs.nixfmt}' },
                },
                options = {
                  nixos = {
                    expr = '(builtins.getFlake "/persist/nixos").nixosConfigurations.rime.options',
                  },
                },
              },
            },
          }
        '';
        "nvim/lsp/lua_ls.lua".text = /* lua */ ''
          return {
            cmd = { '${lib.getExe pkgs.lua-language-server}' },
            filetypes = { 'lua' },
            settings = {
              Lua = {
                completion = { callSnippet = 'Replace' },
                hint = { enable = true },
                runtime = { version = 'LuaJIT' },
                workspace = {
                  library = {
                    [vim.fn.expand('$VIMRUNTIME/lua')] = true,
                    [vim.fn.expand('$VIMRUNTIME/lua/vim/lsp')] = true,
                  },
                },
              },
            },
          }
        '';

        "nvim/plugin/lsp.lua".text = /* lua */ ''
          local servers = {
            'lua_ls',
            'nixd',
          }
          for _, server in ipairs(servers) do
            vim.lsp.enable(server, true)
          end

          vim.api.nvim_create_autocmd('LspAttach', {
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
        "nvim/plugin/treesitter.lua".text = /* lua */ ''
          vim.api.nvim_create_autocmd('FileType', {
            callback = function(args)
              local lang = vim.bo[args.buf].filetype
              if lang and vim.treesitter.query.get(lang, 'highlights') then
                vim.treesitter.start(args.buf, lang)
              end
            end,
          })
        '';
      };
    };
  };
}
