{
  config,
  lib,
  ...
}:
{
  options.lab.postfix = {
    enable = lib.mkEnableOption "enable postfix lab configuration";
    port = lib.mkOption {
      type = lib.types.port;
      default = 25;
      readOnly = true;
    };
  };

  config = lib.mkIf config.lab.postfix.enable {
    sops = {
      secrets = {
        "postfix-token".key = "postfix/token";
      };
      templates = {
        "postfix-password-map" = {
          owner = config.services.postfix.user;
          inherit (config.services.postfix) group;
          content = ''
            [smtp.protonmail.ch]:587 contact@${config.networking.domain}:${
              config.sops.placeholder."postfix-token"
            }
          '';
        };
      };
    };
    services = {
      postfix = {
        enable = true;
        settings.main = {
          inet_interfaces = "loopback-only";
          mynetworks = [ "127.0.0.0/8" ];

          mailbox_size_limit = 51200000;
          message_size_limit = 51200000;
          relayhost = [ "[smtp.protonmail.ch]:587" ];
          smtp_generic_maps = "inline:{ { root@${config.networking.hostName} = contact@${config.networking.domain} } }";
          smtp_sasl_auth_enable = "yes";
          smtp_sasl_password_maps = "texthash:${config.sops.templates.postfix-password-map.path}";
          smtp_sasl_security_options = "noanonymous";
          smtp_tls_loglevel = "1";
          smtp_tls_note_starttls_offer = "yes";
          smtp_tls_security_level = "encrypt";
          smtp_tls_wrappermode = "no";
        };
      };
    };
    systemd.services = {
      postfix = {
        restartTriggers = [
          config.sops.templates."postfix-password-map".path
        ];
      };
    };
  };
}
