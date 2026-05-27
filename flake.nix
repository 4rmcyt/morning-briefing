{
  description = "Galaxy Watch Wakeup Morning Briefing Core Pipeline";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
    in
    {
      # Default formatter for the CI `nix fmt` step
      formatter = forAllSystems (system: nixpkgsFor.${system}.nixpkgs-fmt);

      # Expose package outputs for verification and explicit building
      packages = forAllSystems (system: {
        default = nixpkgsFor.${system}.writers.writePython3Bin "morning-briefing"
          {
            libraries = with nixpkgsFor.${system}.python3Packages; [ caldav requests ];
          }
          (builtins.readFile ./main.py);
      });

      # NixOS Module exported interface
      nixosModules.default = import ./module.nix;

      # Evaluated via `nix flake check` in CI
      checks = forAllSystems (system:
        let pkgs = nixpkgsFor.${system}; in
        {
          buildTest = self.packages.${system}.default;
          lint = pkgs.runCommand "lint" { buildInputs = [ pkgs.python3Packages.flake8 ]; } ''
            flake8 ${./main.py} && touch $out
          '';
        });
    };
}
