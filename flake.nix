{
  description = "A nixvim configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    { nixvim, flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem =
        { pkgs, system, ... }:
        let
          nixvimLib = nixvim.lib.${system};
          nixvim' = nixvim.legacyPackages.${system};
          nvim = nixvim'.makeNixvimWithModule {
            inherit pkgs;
            module = import ./config;
          };

          wiki-link-check = pkgs.writers.writePython3Bin "wiki-link-check"
            { flakeIgnore = [ "E501" ]; }
            (builtins.readFile ./scripts/wiki_link_check.py);

          wiki-reorg = pkgs.writers.writePython3Bin "wiki-reorg"
            { flakeIgnore = [ "E501" "W503" ]; makeWrapperArgs = [ "--prefix" "PATH" ":" "${pkgs.git}/bin" ]; }
            (builtins.readFile ./scripts/wiki_reorg.py);
        in
        {
          checks =
            let
              # Test that the public lib.nixvimConfiguration function works
              nvim-lib = inputs.self.lib.nixvimConfiguration {
                inherit pkgs;
                userConfig = {
                  myNixvim.features = {
                    writing.enable = true;
                  };
                };
              };
            in
            {
              # Run `nix flake check .` to verify that your config is not broken
              default = nixvimLib.check.mkTestDerivationFromNvim {
                inherit nvim;
                name = "nvim";
              };
              nvim-lib = nixvimLib.check.mkTestDerivationFromNvim {
                nvim = nvim-lib;
                name = "nvim-lib";
              };
            };

          packages = {
            # Lets you run `nix run .` to start nixvim
            default = nvim;
            inherit wiki-link-check wiki-reorg;
          };

          devShells.default = pkgs.mkShellNoCC {
            packages = [ wiki-link-check wiki-reorg pkgs.git ];
          };
        };

      flake = {
        lib = {
          # Function for users to configure NixVim with custom options
          # Note: I haven't tested passing pkgs and system yet
          nixvimConfiguration = { pkgs ? null, system ? "x86_64-linux", userConfig }:
            let
              actualPkgs = if pkgs != null then pkgs else inputs.nixpkgs.legacyPackages.${system};
            in
            nixvim.legacyPackages.${system}.makeNixvimWithModule {
              pkgs = actualPkgs;
              module = {
                imports = [ ./config ];
                inherit (userConfig) myNixvim;
              };
            };
        };
      };
    };
}
