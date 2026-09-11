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

      -- Turn a bullet entry like "* someone" into a dated meeting-note link
      -- ("* [[/meeting_notes/YYYY-MM-DD-someone]]") and immediately create/open
      -- it, wherever in the wiki the entry was typed. The leading "/" makes
      -- the link root-relative, so it always lands under meeting_notes/
      -- regardless of which page triggered it (see :h vimwiki-links).
      local function new_meeting_note_from_bullet()
          local row = vim.api.nvim_win_get_cursor(0)[1]
          local line = vim.api.nvim_get_current_line()
          local indent, bullet, rest = line:match("^(%s*)([%*%-]%s+)(.-)%s*$")
          if not rest or rest == "" or rest:match("^%[%[") then
              vim.notify("no bullet entry (e.g. '* someone') on this line", vim.log.levels.WARN)
              return
          end
          local slug = rest:gsub("%s+", "-"):gsub("[^%w%-]", "")
          if slug == "" then
              vim.notify("could not build a note name from this line", vim.log.levels.WARN)
              return
          end
          local date = os.date("%Y-%m-%d")
          local link = "[[/meeting_notes/" .. date .. "-" .. slug .. "]]"
          vim.api.nvim_set_current_line(indent .. bullet .. link)
          vim.api.nvim_win_set_cursor(0, { row, #indent + #bullet })
          vim.cmd("VimwikiFollowLink")
      end

      -- Prose-friendly settings for writing, overriding the code-oriented
      -- globals (textwidth, colorcolumn) set for the rest of the editor.
      vim.api.nvim_create_autocmd("FileType", {
          pattern = { "markdown", "vimwiki" },
          callback = function(args)
              vim.opt_local.wrap = true
              vim.opt_local.linebreak = true
              vim.opt_local.textwidth = 80
              vim.opt_local.colorcolumn = ""
              vim.opt_local.conceallevel = 2
              -- soft-wrap only (via 'wrap'/'linebreak'): don't let
              -- 'textwidth' auto-insert hard line breaks while typing.
              vim.opt_local.formatoptions:remove({ "t", "a" })

              if args.match == "vimwiki" then
                  vim.keymap.set("n", "<leader>mn", new_meeting_note_from_bullet, {
                      buffer = args.buf,
                      desc = "New meeting note from bullet line",
                  })
              end
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
