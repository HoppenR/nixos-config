{
  lib,
  config,
  ...
}:
let
  mkMgmtBssid = bssid: "00" + (lib.substring 2 (lib.stringLength bssid) bssid);
  mkGuestBssid = bssid: "02" + (lib.substring 2 (lib.stringLength bssid) bssid);
in
{
  options.lab.hostapd = {
    enable = lib.mkEnableOption "enable hostapd lab configuration";
    bssid24 = lib.mkOption {
      type = lib.types.strMatching "([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}";
      description = "BSSID MAC address for the 2.4GHz radio";
    };
    bssid5 = lib.mkOption {
      type = lib.types.strMatching "([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}";
      description = "BSSID MAC address for the 5GHz radio";
    };
  };

  config = lib.mkIf config.lab.hostapd.enable {
    sops.secrets = {
      "wifi-mgmt-password".key = "wifi/mgmt-password";
      "wifi-guest-password".key = "wifi/guest-password";
    };

    services.hostapd = {
      enable = true;
      radios = {
        wlan_24 = {
          band = "2g";
          channel = 0;
          countryCode = "SE";
          networks = {
            wlan_24 = {
              ssid = "asgard_24";
              bssid = mkMgmtBssid config.lab.hostapd.bssid24;
              authentication = {
                mode = "wpa3-sae-transition";
                saePasswordsFile = config.sops.secrets."wifi-mgmt-password".path;
                wpaPasswordFile = config.sops.secrets."wifi-mgmt-password".path;
              };
              settings = {
                chanlist = "1 6 11 13";
                hw_mode = "g";
                ieee80211ax = 1;
                ieee80211w = 1;
              };
            };
            wlan_24_guest = {
              ssid = "midgard_24";
              bssid = mkGuestBssid config.lab.hostapd.bssid24;
              authentication = {
                mode = "wpa3-sae-transition";
                saePasswordsFile = config.sops.secrets."wifi-guest-password".path;
                wpaPasswordFile = config.sops.secrets."wifi-guest-password".path;
              };
              settings = {
                chanlist = "1 6 11 13";
                hw_mode = "g";
                ieee80211ax = 1;
                ieee80211w = 1;
              };
            };
          };
          wifi6 = {
            enable = true;
          };
        };
        wlan_5 = {
          band = "5g";
          channel = 0;
          countryCode = "SE";
          networks = {
            wlan_5 = {
              ssid = "asgard_5";
              bssid = mkMgmtBssid config.lab.hostapd.bssid5;
              authentication = {
                mode = "wpa3-sae-transition";
                saePasswordsFile = config.sops.secrets."wifi-mgmt-password".path;
                wpaPasswordFile = config.sops.secrets."wifi-mgmt-password".path;
              };
              settings = {
                chanlist = "36 40 44 48";
                hw_mode = "a";
                ieee80211ac = true;
                ieee80211ax = true;
                ieee80211d = true;
                ieee80211h = true;
                ieee80211n = true;
                wmm_enabled = 1;
              };
            };
            wlan_5_guest = {
              ssid = "midgard_5";
              bssid = mkGuestBssid config.lab.hostapd.bssid5;
              authentication = {
                mode = "wpa3-sae-transition";
                saePasswordsFile = config.sops.secrets."wifi-guest-password".path;
                wpaPasswordFile = config.sops.secrets."wifi-guest-password".path;
              };
              settings = {
                chanlist = "36 40 44 48";
                hw_mode = "a";
                ieee80211ac = true;
                ieee80211ax = true;
                ieee80211d = true;
                ieee80211h = true;
                ieee80211n = true;
                wmm_enabled = 1;
              };
            };
          };
          wifi5 = {
            enable = true;
            operatingChannelWidth = "80";
            capabilities = [
              "MAX-MPDU-11454"
              "SHORT-GI-80"
              "TX-STBC-2BY1"
              "RX-STBC-1"
              "SU-BEAMFORMER"
              "SU-BEAMFORMEE"
              "MU-BEAMFORMER"
            ];
          };
          wifi6 = {
            enable = true;
            multiUserBeamformer = true;
            singleUserBeamformee = true;
            singleUserBeamformer = true;
          };
        };
      };
    };
  };
}
