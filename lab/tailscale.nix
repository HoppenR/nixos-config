{
  lib,
  config,
  ...
}:
{
  options.lab.tailscale = {
    enable = lib.mkEnableOption "enable tailscale lab configuration";
  };

  config = lib.mkIf config.lab.tailscale.enable {
    assertions = [
      {
        assertion = config.services.resolved.enable;
        message = "The lab tailscale module expects resolved for MagicDNS support.";
      }
    ];

    networking.firewall = {
      checkReversePath = "loose";
      trustedInterfaces = [
        config.services.tailscale.interfaceName
      ];
    };

    services = {
      tailscale = {
        enable = true;
        openFirewall = true;
      };
    };

    systemd.services = {
      tailscaled.serviceConfig = {
        Environment = [
          "TS_DEBUG_FIREWALL_MODE=nftables"
        ];
      };
    };
  };
}
