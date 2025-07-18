{ pkgs, ... }:
let
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
  extraPlugins = with pkgs.vimPlugins; [
    vimwiki
  ];

  extraPackages = [
    diaryHelper
    meetingHelper
  ];

  extraConfigLua = ''
    vim.g.vimwiki_list = {
        {
            syntax = "markdown",
            ext = ".wiki",
            path = "~/cloud/home/wiki/notes",
            diary_start_week_monday = true,
            diary_frequency = "weekly",
            vimwiki_table_mappings = 0,
        }
    }
    vim.g.vimwiki_global_ext = 0

    vim.api.nvim_create_autocmd("BufNewFile", {
        pattern = "*/diary/[0-9]*.wiki",
        command = "0r !diary_helper %",
    })

    vim.api.nvim_create_autocmd("BufNewFile", {
        pattern = "*/meeting_notes/*.wiki",
        command = "0r !meeting_helper %",
    })

    vim.cmd("autocmd VimEnter * nested if argc() == 0 | execute 'VimwikiIndex' | endif")
  '';
}

