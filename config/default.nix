{
  # Import all your configuration modules here
  imports = [
    ./bufferline.nix
    ./lualine.nix
    ./git.nix
  ];

  colorschemes.gruvbox.enable = true;

  opts = {

    ignorecase = true; # make searches with lower case characters case insensitive
    smartcase = true; # search is case sensitive only if it contains uppercase chars
    inccommand = "nosplit"; # show preview in buffer while doing find and replace

    ai = true; # Copy indent from current line when starting a new one
    autoread = true; # Set to auto read when a file is changed from the outside
    backspace = "indent,eol,start"; # allow backspace over indents, etc.
    cmdheight = 2; # number of screen lines for command line

    colorcolumn = "80";
    cursorline = true; # highlight line in which the cursor is
    encoding = "utf-8"; # Set utf8 as standard encoding
    expandtab = true; # Use spaces instead of tabs
    ffs = "unix,dos,mac"; # Use Unix as the standard file type
    hidden = true; # keep buffers open - preserves history
    laststatus = 2; # always show a status line
    lbr = true; # Linebreak on 500 characters
    list = true; # turn whitespace display on

    # Set custom strings for list mode
    # - tabulations are shown as ‒▶
    # - trailing spaces are shown as ·
    # - multiple non-leading consecutive spaces are shown as bullets (·)
    # - non-breakable spaces are shown as ⎕
    listchars = "tab:‒▶,trail:·,multispace:·,lead: ,nbsp:⎕";
    backup = false;
    errorbells = false; # No annoying sound on errors
    foldenable = true; # Enable folds so that I get used to them
    swapfile = false;
    visualbell = false; # again: no sounds
    nu = true; # Show line numbers
    ruler = true; # Always show current position
    shiftwidth = 4; # 1 tab == 4 spaces
    smartindent = true; # Smart indent
    smarttab = true; # Be smart when using tabs ;)
    spell = true; # enable spell checking
    spelllang = "en"; # default spellcheck language
    tabstop = 4; # ...
    tm = 500; # ...
    tw = 500; # text width
    wildmenu = true; # enhanced command-line completion mode
    wrap = true; # Wrap lines
    writebackup = true; # make a backup before overwriting a file
  };
}
