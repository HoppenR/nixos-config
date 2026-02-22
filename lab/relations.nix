{
  config,
  lib,
  ...
}:
let
  relations = {
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
    syncthing = {
      enabled = true;
      clients = [ "rime" ];
      host = "skadi";
    };
    zfsReplication = {
      enabled = true;
      clients = [ "skadi" ];
      host = "hoddmimir";
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
