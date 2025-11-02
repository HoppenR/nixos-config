{
  description = "NixOS on my VM";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {nixpkgs, ...} @ inputs: let
    system = "x86_64-linux";
  in {
    nixosConfigurations = {
      nixvm = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs system;};

        modules = [
          ./configuration.nix
        ];
      };
    };
  };
}
