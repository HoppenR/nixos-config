{
  config,
  lib,
  pkgs,
  ...
}:
let
  sp = builtins.fromJSON "\"\\u2007\"";
  greeingCommon = (
    lib.strings.escapeShellArg ''
      ${sp}        | \| |_ _|\ \/ / (\_/)  / _ \/ __|        ${sp}
      ${sp}        | .`  | |  >  < (='.'=)| (_) \__ \        ${sp}
      ${sp}        |_|\_|___|/_/\_\(")_(")_\___/|___/        ${sp}
    ''
  );
  roleArt = {
    skadi = lib.strings.escapeShellArg ''
      ${sp}         * / __ | |/ /  /_\  |   \|_ _| *         ${sp}
      ${sp}          *\__ \| ' <  / * \ ┼─|)  | | *          ${sp}
      ${sp}         * |___/ _|\_\/_/ \_\|___/|___| *         ${sp}
      ${sp}          * ━━━━━━━━━━━━━━━━━━━━━━━━━━ *          ${sp}
    '';
    hoddmimir = lib.strings.escapeShellArg ''
      ${sp}| || |/ _ \|   \|   \|  \|/  |_ _||  \/  |_ _| _ \${sp}
      ${sp}| __ | (_) | |) | |) | |\|/|  | | | |\/|  | |    /${sp}
      ${sp}|_||_|\___/|___/|___/|_| | |_|___||_|  |_|___|_|_\${sp}
      ${sp}            -------------┴-------------           ${sp}
    '';
    rime = lib.strings.escapeShellArg ''
      ${sp}    .     :    |  _ \_ _|| \/ | __| ..  .    .    ${sp}
      ${sp} . ..:  . .    | `  /| | |    | __|       :       ${sp}
      ${sp}  :    .  :    |__|_\___||_||_|___|   : .   :     ${sp}
      ${sp}   /  :/ .  /    /    /    /    /    /   :/    /  ${sp}
      ${sp}--------------------------------------------------${sp}
    '';
  };
  greetingEnding = lib.strings.escapeShellArg ''
    NixOS ${config.system.nixos.version}
  '';
  greeting = greeingCommon + roleArt.${config.networking.hostName} + greetingEnding;

  cmdAndArgsArray = [
    "${lib.getExe pkgs.tuigreet}"
    "--greeting ${greeting}"
    "--user-menu"
    "--time"
    "--theme '${config.lab.greetd.theme}'"
    "--time-format %R"
  ]
  ++ lib.optional config.lab.greetd.useZshLogin "--cmd 'zsh --login'";
in
{
  options.lab.greetd = {
    enable = lib.mkEnableOption "enable greetd lab configuration";
    useZshLogin = lib.mkEnableOption "use a fallback login for when no sessions exist";
    theme = lib.mkOption {
      type = lib.types.str;
      default = "container=black;text=white";
      description = "The greetd theme string";
    };
  };

  config = lib.mkIf config.lab.greetd.enable {
    services.greetd = {
      enable = true;
      useTextGreeter = true;
      settings = {
        default_session = {
          command = lib.concatStringsSep " " cmdAndArgsArray;
        };
        terminal = {
          vt = 1;
        };
      };
    };
  };
}
