{
  description = "A nixvim configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
            module = import ./config; # import the module directly
            # You can use `extraSpecialArgs` to pass additional arguments to your module files
            extraSpecialArgs = {
              # inherit (inputs) foo;
            };
          };
          nvim-dev = nvim.extend {
            imports = [
              ./config/languages/bash.nix
              ./config/languages/nix.nix
            ];
          };
          nvim-office = nvim.extend {
            imports = [
              ./config/languages/bash.nix
              ./config/languages/nix.nix
              ./config/vimwiki.nix
              ./config/markdown-preview.nix
              ./config/goyo.nix
            ];
          };
        in
        {
          checks = {
            # Run `nix flake check .` to verify that your config is not broken
            default = nixvimLib.check.mkTestDerivationFromNvim {
              inherit nvim;
              name = "nvim";
            };
            nvim-dev = nixvimLib.check.mkTestDerivationFromNvim {
              nvim = nvim-dev;
              name = "nvim-dev";
            };
            nvim-office = nixvimLib.check.mkTestDerivationFromNvim {
              nvim = nvim-office;
              name = "nvim-office";
            };
          };

          packages = {
            # Lets you run `nix run .` to start nixvim
            default = nvim;
            inherit nvim-dev;
            inherit nvim-office;
          };
        };

      flake = {
        lib = {
          # Function for users to configure NixVim with custom options
          nixvimConfiguration = { pkgs ? null, system ? "x86_64-linux", userConfig }:
            let
              actualPkgs = if pkgs != null then pkgs else inputs.nixpkgs.legacyPackages.${system};
            in
            nixvim.legacyPackages.${actualPkgs.system}.makeNixvimWithModule {
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
