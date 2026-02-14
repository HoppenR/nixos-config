{
  config,
  lib,
  ...
}:
{
  options.lab.postfix = {
    enable = lib.mkEnableOption "enable postfix lab configuration";
    bridgePodman = lib.mkEnableOption "access from podman0 bridge";
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
            [smtp.protonmail.ch]:587 contact@${config.lab.domainName}:${config.sops.placeholder."postfix-token"}
          '';
        };
      };
    };
    services = {
      postfix = {
        enable = true;
        settings.main = {
          inet_interfaces = "all";
          mynetworks = [ "127.0.0.0/8" ] ++ (lib.optional config.lab.postfix.bridgePodman "10.88.0.0/16");

          relayhost = [ "[smtp.protonmail.ch]:587" ];
          smtp_generic_maps = "inline:{ { root@${config.networking.hostName} = contact@${config.lab.domainName} } }";
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
    networking.firewall.extraInputRules = lib.mkIf config.lab.postfix.bridgePodman ''
      iifname "podman0" tcp dport 25 accept
    '';
  };
}
