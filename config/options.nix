{ lib, ... }:
{
  options.myNixvim = {
    features = {
      completion = {
        enable = lib.mkEnableOption "autocompletion";
      };
      development = {
        enable = lib.mkEnableOption "LSP and development tools";
        nix = {
          enable = lib.mkEnableOption "Nix language support";
        };
        bash = {
          enable = lib.mkEnableOption "Bash language support";
        };
        rust = {
          enable = lib.mkEnableOption "Rust language support";
        };
        cpp = {
          enable = lib.mkEnableOption "C++ language support";
        };
      };
      writing = {
        enable = lib.mkEnableOption "writing tools (vimwiki, markdown-preview, goyo)";
      };
      spellcheck = {
        enable = lib.mkEnableOption "grammar checking with write-good";
      };
    };
  };

  config = {
    myNixvim.features = {
      completion.enable = lib.mkDefault true;
      spellcheck.enable = lib.mkDefault true;
      development = {
        enable = lib.mkDefault true;
        nix.enable = lib.mkDefault true;
        bash.enable = lib.mkDefault true;
        rust.enable = lib.mkDefault false;
        cpp.enable = lib.mkDefault false;
      };
      writing.enable = lib.mkDefault false;
    };
  };
}
