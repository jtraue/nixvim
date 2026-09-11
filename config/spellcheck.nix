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

    # LanguageTool-backed grammar/style checking as an LSP, delegated to the
    # already-running `services.languagetool` HTTP server (localhost:8081)
    # instead of spinning up ltex's own bundled instance.
    plugins.lsp = {
      enable = true;
      servers.ltex = {
        enable = true;
        package = pkgs.ltex-ls-plus;
        cmd = [ "${pkgs.ltex-ls-plus}/bin/ltex-ls-plus" ];
        filetypes = [
          "markdown"
          "vimwiki"
        ];
        # Prose files don't need real project-root resolution, and the wiki
        # isn't necessarily a git repo - the default ".git" root marker would
        # otherwise silently prevent ltex from ever autostarting there.
        extraOptions.root_dir = lib.nixvim.mkRaw ''
          function(bufnr, on_dir)
            on_dir(vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
          end
        '';
        settings = {
          language = "auto";
          languageToolHttpServerUri = "http://localhost:8081";
        };
      };
    };
  };
}
