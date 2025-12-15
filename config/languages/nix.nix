{
  plugins = {
    lsp.servers.nixd.enable = true;
    none-ls.sources = {

      diagnostics = {
        statix.enable = true;
      };
      formatting = {
        nixpkgs_fmt.enable = true;
      };
    };
  };
}
