{
  config,
  lib,
  ...
}:
let
  relations = {
    adguardhome = {
      enabled = true;
      clients = lib.singleton "skadi";
      host = "bifrost";
    };
    proxmox = {
      enabled = true;
      clients = [ "skadi" ];
      host = "yggdrasil";
    };
    rcloneMounts = {
      enabled = true;
      clients = [ "skadi" ];
      host = "hoddmimir";
    };
    streams = {
      enabled = true;
      clients = [ "rime" ];
      host = "skadi";
    };
    zfsReplication = {
      enabled = true;
      clients = [ "skadi" ];
      host = "hoddmimir";
    };
    zed = {
      enabled = true;
      clients = [ "hoddmimir" ];
      host = "skadi";
    };
  };

  hostName = config.networking.hostName;
  decorate =
    name: rel:
    rel
    // rec {
      isHost = hostName == rel.host;
      isClient = builtins.elem hostName rel.clients;
      isActive = rel.enabled && (isHost || isClient);
    };
in
{
  config._module.args = {
    relations = lib.mapAttrs decorate relations;
  };
}
