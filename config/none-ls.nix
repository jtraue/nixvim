{
  plugins.none-ls = {
    enable = true;
    sources = {
      diagnostics = {
        statix.enable = true;
      };
      formatting = {
        nixpkgs_fmt.enable = true;
      };
    };
  };
}
