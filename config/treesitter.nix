{
  plugins = {
    treesitter = {
      enable = true;
      nixGrammars = true;
      settings.indent.enable = true;
    };
    rainbow-delimiters.enable = true;
  };
}
