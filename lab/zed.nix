{
  config,
  identities,
  inventory,
  lib,
  pkgs,
  relations,
  net,
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
            mynetworks = map (client: "${net.ip net.mgmt client}/32") rel.clients;
          };
        };
        networking.firewall.extraInputRules = lib.concatMapStrings (client: ''
          ip saddr ${net.ip net.mgmt client} tcp dport ${toString config.lab.postfix.port} iifname "vlan-mgmt" accept
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
            host = net.ip net.mgmt rel.host;
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
