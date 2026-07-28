{
  config,
  lib,
  pkgs,
  monitors,
  osConfig,
  ...
}:
let
  mod_apps = "MOD3";
  mod_hypr = "MOD5";
  mod_move = "SUPER";

  workspaceCharacters = lib.stringToCharacters "qwertyuiop";
  workspaceKeys = lib.listToAttrs (lib.imap1 (n: k: lib.nameValuePair k n) workspaceCharacters);
in
{
  lab = {
    hyprland = {
      uwsm = osConfig.programs.hyprland.withUWSM;
      monitors = monitors;
      binds = [
        # --- Application Launchers (hl.dsp.exec_raw) ---
        {
          mods = [ mod_apps ];
          key = "RETURN";
          exec_raw = [ ];
          settings.terminal = true;
        }
        {
          mods = [ mod_apps ];
          key = "a";
          exec_raw = lib.getExe pkgs.pavucontrol;
        }
        {
          mods = [ mod_apps ];
          key = "d";
          exec_raw = lib.getExe pkgs.hyprlauncher;
        }
        {
          mods = [ mod_apps ];
          key = "e";
          exec_raw = lib.getExe config.programs.neovim.finalPackage;
          settings.terminal = true;
        }
        {
          mods = [ mod_apps ];
          key = "w";
          exec_raw = lib.getExe config.programs.firefox.finalPackage;
        }
        {
          mods = [ mod_apps ];
          key = "f";
          exec_raw = [
            (lib.getExe pkgs.grimblast)
            "--notify"
            "save"
            "area"
            "${config.home.homeDirectory}/Pictures/Screenshots/snapshot_$(date +%F_%H-%M-%S).png"
          ];
        }
        # --- Window Core Actions (hl.dsp.window) ---
        {
          mods = [
            mod_hypr
            "SHIFT"
          ];
          key = "q";
          "window.close" = [ ];
        }
        {
          mods = [ mod_hypr ];
          key = "Space";
          "window.float".action = "toggle";
        }
        {
          mods = [ mod_hypr ];
          key = "f";
          "window.fullscreen".action = "toggle";
        }
        # --- Directional Navigation (hl.dsp.focus hl.dsp.window.move hl.dsp.window.resize) ---
        {
          mods = [ mod_move ];
          key = "h";
          focus.direction = "l";
        }
        {
          mods = [ mod_move ];
          key = "j";
          focus.direction = "d";
        }
        {
          mods = [ mod_move ];
          key = "k";
          focus.direction = "u";
        }
        {
          mods = [ mod_move ];
          key = "l";
          focus.direction = "r";
        }
        {
          mods = [
            mod_move
            "SHIFT"
          ];
          key = "h";
          "window.move".direction = "l";
        }
        {
          mods = [
            mod_move
            "SHIFT"
          ];
          key = "j";
          "window.move".direction = "d";
        }
        {
          mods = [
            mod_move
            "SHIFT"
          ];
          key = "k";
          "window.move".direction = "u";
        }
        {
          mods = [
            mod_move
            "SHIFT"
          ];
          key = "l";
          "window.move".direction = "r";
        }
        {
          mods = [ mod_hypr ];
          key = "l";
          "window.resize" = {
            x = 50;
            y = 0;
            relative = true;
          };
          options.repeating = true;
        }
        {
          mods = [ mod_hypr ];
          key = "h";
          "window.resize" = {
            x = -50;
            y = 0;
            relative = true;
          };
          options.repeating = true;
        }
        {
          mods = [ mod_hypr ];
          key = "k";
          "window.resize" = {
            x = 0;
            y = -50;
            relative = true;
          };
          options.repeating = true;
        }
        {
          mods = [ mod_hypr ];
          key = "j";
          "window.resize" = {
            x = 0;
            y = 50;
            relative = true;
          };
          options.repeating = true;
        }
        # --- Hardware & Media Controls (hl.dsp.exec_raw) ---
        {
          key = "XF86AudioRaiseVolume";
          exec_raw = [
            "${pkgs.wireplumber}/bin/wpctl"
            "set-volume"
            "-l"
            "1.0"
            "@DEFAULT_AUDIO_SINK@"
            "5%+"
          ];
          options.repeating = true;
        }
        {
          key = "XF86AudioLowerVolume";
          exec_raw = [
            "${pkgs.wireplumber}/bin/wpctl"
            "set-volume"
            "-l"
            "1.0"
            "@DEFAULT_AUDIO_SINK@"
            "5%-"
          ];
          options.repeating = true;
        }
        {
          key = "XF86AudioMute";
          exec_raw = [
            "${pkgs.wireplumber}/bin/wpctl"
            "set-mute"
            "@DEFAULT_AUDIO_SINK@"
            "toggle"
          ];
        }
        {
          key = "XF86MonBrightnessUp";
          exec_raw = [
            (lib.getExe pkgs.brightnessctl)
            "--class=backlight"
            "set"
            "+20%"
          ];
          options.repeating = true;
        }
        {
          key = "XF86MonBrightnessDown";
          exec_raw = [
            (lib.getExe pkgs.brightnessctl)
            "--class=backlight"
            "set"
            "20%-"
          ];
          options.repeating = true;
        }
        {
          mods = [ mod_move ];
          key = "mouse:272";
          "window.drag" = [ ];
          options.mouse = true;
        }
        {
          mods = [ mod_move ];
          key = "mouse:273";
          "window.resize" = [ ];
          options.mouse = true;
        }
      ]
      # --- Workspace Focus (hl.dsp.focus.workspace) ---
      ++ (lib.mapAttrsToList (key: num: {
        mods = [ mod_move ];
        inherit key;
        focus.workspace = num;
      }) workspaceKeys)
      # --- Move Window to Workspace (hl.dsp.window.move) ---
      ++ (lib.mapAttrsToList (key: num: {
        mods = [
          mod_move
          "SHIFT"
        ];
        inherit key;
        "window.move" = {
          workspace = num;
          follow = false;
        };
      }) workspaceKeys)
      # --- Follow Window to Workspace (hl.dsp.window.move) ---
      ++ (lib.mapAttrsToList (key: num: {
        mods = [
          mod_move
          "CTRL"
          "SHIFT"
        ];
        inherit key;
        "window.move" = {
          workspace = num;
          follow = true;
        };
      }) workspaceKeys);
    };
  };
}
