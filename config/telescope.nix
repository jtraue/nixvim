{ pkgs, ... }:
{
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
  extraPackages = [ pkgs.ripgrep ]; # for live_grep
}
