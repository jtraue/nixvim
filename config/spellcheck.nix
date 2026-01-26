{ pkgs, lib, config, ... }:
let
  cfg = config.myNixvim.features;
in
{
  config = lib.mkIf cfg.spellcheck.enable {
    extraPackages = with pkgs; [
      nodePackages.write-good
    ];

    plugins.none-ls = {
      enable = true;
      sources = {
        diagnostics = {
          write_good = {
            enable = true;
          };
        };
      };
    };
  };
}
