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
    "ehci_pci"
    "sd_mod"
    "sr_mod"
    "uhci_hcd"
    "usbhid"
    "virtio_pci"
    "virtio_scsi"
    "xhci_pci"
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
