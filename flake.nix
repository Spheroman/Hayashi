{
  description = "Hayashi: a Wayland compositor with nested workspaces, and its Quickshell shell";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        hayashi-shell = pkgs.callPackage ./nix/shell.nix { };
        hayashi-plymouth-theme = pkgs.callPackage ./nix/plymouth-theme.nix { };
        default = hayashi-shell;
      });

      homeManagerModules = {
        hayashi-shell = import ./nix/hm-shell.nix self;
        default = self.homeManagerModules.hayashi-shell;
      };

      nixosModules = {
        hayashi-shell = import ./nix/nixos-shell.nix self;
        default = self.nixosModules.hayashi-shell;
      };
    };
}
