{
  config,
  lib,
  net,
  ...
}:
{
  options.lab = {
    openssh = {
      enable = lib.mkEnableOption "enable openssh lab config";
      namespace = lib.mkEnableOption "enable namespace extension";
    };
  };

  config = lib.mkIf config.lab.openssh.enable (
    lib.mkMerge [
      {
        services.openssh = {
          enable = true;
          listenAddresses = [
            {
              addr = net.ip net.mgmt config.networking.hostName;
              port = 22;
            }
            {
              addr = "[${net.ip6 net.mgmt config.networking.hostName}]";
              port = 22;
            }
          ];
          hostKeys = [
            {
              path = "/persist/etc/ssh/ssh_host_ed25519_key";
              type = "ed25519";
            }
          ];
          settings = {
            AuthenticationMethods = "publickey";
            KbdInteractiveAuthentication = false;
            PasswordAuthentication = false;
            PermitRootLogin = "no";
            UseDns = true;
          };
        };
      }
      (lib.mkIf config.lab.openssh.namespace {
        lab.namespaces = {
          mgmt.firewall.tcp = [ 22 ];
        };
        services.openssh = {
          openFirewall = false;
        };
        systemd.services.sshd = {
          after = [ "setup-network@mgmt.service" ];
          requires = [ "setup-network@mgmt.service" ];
          serviceConfig = {
            BindPaths = [
              "/etc/netns/ns-mgmt/hosts:/etc/hosts"
              "/etc/netns/ns-mgmt/resolv.conf:/etc/resolv.conf"
            ];
            NetworkNamespacePath = "/run/netns/ns-mgmt";
          };
        };
      })
    ]
  );
}
