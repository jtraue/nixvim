{ pkgs, ... }:
{
  plugins.web-devicons.enable = true;
  plugins.web-devicons.autoLoad = true;

  plugins.bufferline = {
    enable = true;
    settings.options.diagnostics = "nvim_lsp";
  };

  # LSP progress indicator
  plugins.fidget = {
    enable = true;
    settings.progress = {
      suppress_on_insert = true;
      ignore_done_already = true;
      poll_rate = 1;
    };
  };

  plugins.gitsigns.enable = true;

  # Status line
  plugins.lualine = {
    enable = true;
    settings.options = {
      theme = "gruvbox";
      section_separators = { left = ""; right = ""; };
      component_separators = { left = ""; right = ""; };
    };
  };

  # Fuzzy finder
  plugins.telescope = {
    enable = true;
    extensions = {
      file-browser.enable = true;
      fzf-native.enable = true;
    };
    keymaps = {
      "<leader>ff" = {
        action = "find_files";
        options = {
          desc = "Find project files";
        };
      };
      "<leader>fg" = {
        action = "live_grep";
        options = {
          desc = "Grep (root dir)";
        };
      };
      "<leader>fb" = {
        action = "buffers";
        options = {
          desc = "+buffer";
        };
      };
    };
  };
  extraPackages = [ pkgs.ripgrep ];

  # Keybinding discovery
  plugins.which-key = {
    enable = true;
    settings.keys = {
      scroll_down = "<c-d>";
      scroll_up = "<c-u>";
    };
  };

  # Auto-pairing brackets
  plugins.nvim-autopairs.enable = true;

  plugins.comment.enable = true;

  # Syntax highlighting and parsing
  plugins = {
    treesitter = {
      enable = true;
      nixGrammars = true;
      settings.indent.enable = true;
    };
    rainbow-delimiters.enable = true;
  };
}
