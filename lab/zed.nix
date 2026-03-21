{
  config,
  identities,
  inventory,
  lib,
  pkgs,
  relations,
  ...
}:
let
  rel = relations.zed;
in
{
  options.lab.zed = {
    enable = lib.mkEnableOption "enable zed email configuration";
  };

  config = lib.mkIf rel.isActive (
    lib.mkMerge [
      (lib.mkIf rel.isHost {
        services.postfix = {
          settings.main = {
            inet_interfaces = "all";
            mynetworks = map (client: "${inventory.${client}.ipv4}/32") rel.clients;
          };
        };
        networking.firewall.extraInputRules = lib.concatMapStrings (client: ''
          ip saddr ${inventory.${client}.ipv4} tcp dport ${toString config.lab.postfix.port} iifname "lan0" accept
        '') rel.clients;
      })
      (lib.mkIf rel.isClient {
        programs.msmtp = {
          enable = true;
          defaults = {
            port = 25;
            tls = false;
          };
          extraConfig = ''
            set_to_header on
          '';
          accounts.default = {
            host = inventory.${rel.host}.ipv4;
            from = "ZED Service <contact@${config.networking.domain}>";
          };
        };
        services.zfs.zed = {
          settings = {
            ZED_EMAIL_ADDR = [ identities.people.christoffer.email ];
            ZED_EMAIL_PROG = lib.getExe pkgs.msmtp;
            ZED_EMAIL_OPTS = "--read-recipients @ADDRESS@";
            ZED_NOTIFY_VERBOSE = true;
          };
        };
      })
    ]
  );
}
