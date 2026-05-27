{
  description = "Galaxy Watch Wakeup Morning Briefing Core Pipeline";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
    in
    {
      packages = forAllSystems (system: {
        default = nixpkgsFor.${system}.writers.writePython3Bin "morning-briefing" {
          libraries = with nixpkgsFor.${system}.python3Packages; [
            caldav
            requests
          ];
        } (builtins.readFile ./main.py);
      });

      nixosModules.default = import ./module.nix;
    };
}
