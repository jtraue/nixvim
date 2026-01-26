{ lib, ... }:
{
  options.myNixvim = {
    enableSpellcheck = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable prose linting with write-good";
    };
  };
}
