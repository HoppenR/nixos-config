{ ... }:
{
  home.stateVersion = "25.11";

  # TODO: make this into a common setting like lab.osc52, lab.headless, or
  #       alternatively add this when lan.openssh is enabled
  programs.neovim = {
    initLua = /* lua */ ''
      vim.g.clipboard = {
        name = 'OSC 52',
        copy = {
          ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
          ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
        },
        paste = {
          ['+'] = require('vim.ui.clipboard.osc52').paste('+'),
          ['*'] = require('vim.ui.clipboard.osc52').paste('*'),
        },
      }
    '';
  };
}
