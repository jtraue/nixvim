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
          # nvim-full enables all features
          nvim-full = nvim.extend {
            myNixvim.features = {
              writing.enable = true;
              development.rust.enable = true;
              development.cpp.enable = true;
            };
          };
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
              nvim-full = nixvimLib.check.mkTestDerivationFromNvim {
                nvim = nvim-full;
                name = "nvim-full";
              };
              nvim-lib = nixvimLib.check.mkTestDerivationFromNvim {
                nvim = nvim-lib;
                name = "nvim-lib";
              };
            };

          packages = {
            # Lets you run `nix run .` to start nixvim
            default = nvim;
            inherit nvim-full;
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
