{
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "virtio_pci"
    "sr_mod"
    "virtio_blk"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/987a12e0-718f-4d34-86f4-5647f35212db";
    fsType = "btrfs";
    options = [
      "subvol=@"
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/987a12e0-718f-4d34-86f4-5647f35212db";
    fsType = "btrfs";
    options = [
      "subvol=@home"
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/1D3C-A97C";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [
    {
      device = "/dev/disk/by-uuid/6518778a-3ca5-4bd2-91bd-56125a387dd0";
      options = [ "discard" ];
    }
  ];

  networking = {
    defaultGateway = "192.168.122.1";
    interfaces.enp1s0 = {
      ipv4.addresses = [
        {
          address = "192.168.122.155";
          prefixLength = 24;
        }
      ];
      ipv6.addresses = [
        {
          address = "fe80::5054:ff:fe28:611b";
          prefixLength = 64;
        }
      ];
      useDHCP = false;
    };
    resolvconf.enable = false;
    useDHCP = false;
    # wireless.enable = true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
