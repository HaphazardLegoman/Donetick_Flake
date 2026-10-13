{
  description = "Donetick - open-source task and chore management application";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forEachSystem = lib.genAttrs supportedSystems;
    in
    {
      packages = forEachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          donetick = pkgs.callPackage ./pkgs/donetick.nix { };
        in
        {
          inherit donetick;
          default = donetick;
        });

      overlays.default = final: prev: {
        donetick = final.callPackage ./pkgs/donetick.nix { };
      };

      nixosModules.donetick = import ./nix/nixos-module.nix { inherit self; };

      checks = forEachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          nixos-module = pkgs.callPackage ./nix/check-module.nix { inherit self; };
        });
    };
}
