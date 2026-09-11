{ pkgs, lib, config, ... }:
let
  cfg = config.myNixvim.features;
  diaryHelper = pkgs.writeShellScriptBin "diary_helper" ''
    cat << EOF
    # $(date +'%Y WEEK %U')

    # TODO

    EOF
  '';
  meetingHelper = pkgs.writeShellScriptBin "meeting_helper" ''
    cat << EOF
    # $(date +'%Y-%m-%d')

    ## Attendees

    ## Agenda

    [toc]

    ## Action Items

    EOF
  '';
in
{
  config = lib.mkIf cfg.writing.enable {
    extraPackages = [
      diaryHelper
      meetingHelper
    ];

    plugins.vimwiki = {
      enable = true;
      settings = {
        global_ext = 0;
        list = [
          {
            syntax = "markdown";
            ext = ".wiki";
            path = "~/cloud/home/wiki/notes";
            diary_start_week_monday = true;
            diary_frequency = "weekly";
            vimwiki_table_mappings = 0;
          }
        ];
      };
    };

    # vimwiki buffers keep filetype "vimwiki", not "markdown" - tell treesitter
    # (and therefore render-markdown below) to parse them as markdown anyway.
    extraConfigLua = ''
      vim.treesitter.language.register("markdown", "vimwiki")

      vim.api.nvim_create_autocmd("BufNewFile", {
          pattern = "*/diary/[0-9]*.wiki",
          command = "0r !diary_helper %",
      })

      vim.api.nvim_create_autocmd("BufNewFile", {
          pattern = "*/meeting_notes/*.wiki",
          command = "0r !meeting_helper %",
      })

      vim.cmd("autocmd VimEnter * nested if argc() == 0 | execute 'VimwikiIndex' | endif")

      -- Prose-friendly settings for writing, overriding the code-oriented
      -- globals (textwidth, colorcolumn) set for the rest of the editor.
      vim.api.nvim_create_autocmd("FileType", {
          pattern = { "markdown", "vimwiki" },
          callback = function()
              vim.opt_local.wrap = true
              vim.opt_local.linebreak = true
              vim.opt_local.textwidth = 80
              vim.opt_local.colorcolumn = ""
              vim.opt_local.conceallevel = 2
          end,
      })
    '';

    # In-editor markdown rendering (headings, bold, lists, tables, ...)
    plugins.render-markdown = {
      enable = true;
      settings.file_types = [
        "markdown"
        "vimwiki"
      ];
    };

    # Distraction-free writing
    plugins.zen-mode = {
      enable = true;
      settings.plugins.twilight.enabled = true;
    };
    plugins.twilight.enable = true;

    keymaps = [
      {
        mode = "n";
        key = "<leader>zz";
        action = "<cmd>ZenMode<CR>";
        options.desc = "Toggle zen mode";
      }
    ];
  };
}
