{ lib, config, ... }:
let
  cfg = config.myNixvim.features.development;
in
{
  config = lib.mkIf cfg.enable {
    plugins = {
      trouble.enable = true;

      lsp = {
        enable = true;

        servers = {
          # Nix language support
          nixd.enable = lib.mkIf cfg.nix.enable true;

          # Bash language support
          bashls.enable = lib.mkIf cfg.bash.enable true;

          # Rust language support
          rust_analyzer = lib.mkIf cfg.rust.enable {
            enable = true;
            installCargo = false;
            installRustc = false;
          };

          # C++ language support
          clangd.enable = lib.mkIf cfg.cpp.enable true;
        };
      };

      lspsaga = {
        enable = true;
        settings.code_action.extend_git_signs = true;
      };

      none-ls = {
        enable = true;
        sources = lib.mkIf cfg.nix.enable {
          diagnostics = {
            statix.enable = true;
          };
          formatting = {
            nixpkgs_fmt.enable = true;
          };
        };
      };
    };

    keymaps = [
      {
        mode = "n";
        key = "gd";
        action = "<cmd>Lspsaga finder def<CR>";
        options = {
          desc = "Goto Definition";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "gr";
        action = "<cmd>Lspsaga finder ref<CR>";
        options = {
          desc = "Goto References";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "gI";
        action = "<cmd>Lspsaga finder imp<CR>";
        options = {
          desc = "Goto Implementation";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "gT";
        action = "<cmd>Lspsaga peek_type_definition<CR>";
        options = {
          desc = "Type Definition";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "K";
        action = "<cmd>Lspsaga hover_doc<CR>";
        options = {
          desc = "Hover";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>cw";
        action = "<cmd>Lspsaga outline<CR>";
        options = {
          desc = "Outline";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>cr";
        action = "<cmd>Lspsaga rename<CR>";
        options = {
          desc = "Rename";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>ca";
        action = "<cmd>Lspsaga code_action<CR>";
        options = {
          desc = "Code Action";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>cd";
        action = "<cmd>Lspsaga show_line_diagnostics<CR>";
        options = {
          desc = "Line Diagnostics";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "[d";
        action = "<cmd>Lspsaga diagnostic_jump_next<CR>";
        options = {
          desc = "Next Diagnostic";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "]d";
        action = "<cmd>Lspsaga diagnostic_jump_prev<CR>";
        options = {
          desc = "Previous Diagnostic";
          silent = true;
        };
      }
    ];
  };
}
