{ pkgs, lib, config, ... }:
{
  extraPackages = lib.optionals config.myNixvim.enableSpellcheck (with pkgs; [
    nodePackages.write-good
  ]);

  plugins.none-ls = {
    enable = true;
    sources = lib.mkIf config.myNixvim.enableSpellcheck {
      diagnostics = {
        write_good = {
          enable = true;
        };
      };
    };
  };
}
