{
  plugins = {
    lsp = {
      enable = true;
      servers = {
        bashls.enable = true;
        nixd.enable = true;
      };
      keymaps.lspBuf = {
        "K" = "hover";
      };
    };
    lsp-lines = {
      enable = true;
      currentLine = true;
    };
  };
}
