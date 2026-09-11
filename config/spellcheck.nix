{ pkgs, lib, config, ... }:
let
  cfg = config.myNixvim.features;

  # Neovim's runtime only bundles English spell files; other languages must
  # be fetched separately (see `:h spell`). Pinned from the official vim
  # runtime spell mirror so `:set spelllang=de` works offline/reproducibly.
  vimSpellDe = pkgs.runCommand "vim-spell-de" { } ''
    mkdir -p $out/spell
    cp ${pkgs.fetchurl {
      url = "https://ftp.nluug.nl/vim/runtime/spell/de.utf-8.spl";
      hash = "sha256-c8cQfqM5hWzb6SHeuSpFk5xN5uucByYdobndGfaDo9E=";
    }} $out/spell/de.utf-8.spl
    cp ${pkgs.fetchurl {
      url = "https://ftp.nluug.nl/vim/runtime/spell/de.utf-8.sug";
      hash = "sha256-E9Ds+Shj2J72DNSopesqWhOg6Pm6jRxqvkerqFcUqUg=";
    }} $out/spell/de.utf-8.sug
  '';
in
{
  config = lib.mkIf cfg.spellcheck.enable {
    extraPackages = with pkgs; [
      nodePackages.write-good
    ];

    extraPlugins = [ vimSpellDe ];

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
