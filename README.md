# NixVim Configuration

A modular Neovim configuration built with NixVim.

## Quick Start

```bash
# Run default configuration
nix run github:jtraue/nixvim

# Run with all features enabled
nix run github:jtraue/nixvim#nvim-full
```

## Features

| Feature | Default | Description |
|---------|---------|-------------|
| `completion.enable` | true | Autocompletion (nvim-cmp) |
| `spellcheck.enable` | true | Grammar checking (write-good) |
| `development.enable` | true | LSP, lspsaga, trouble |
| `development.nix.enable` | true | Nix support (nixd, statix, nixpkgs-fmt) |
| `development.bash.enable` | true | Bash support (bashls) |
| `writing.enable` | false | Writing tools (vimwiki, markdown-preview, goyo) |

## Usage in NixOS

> **Note:** The resulting package uses nixpkgs defined in this flake. You cannot override them from your own configuration.

### Using the library function

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixvim-config.url = "github:jtraue/nixvim";
  };

  outputs = { nixpkgs, nixvim-config, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [{
        environment.systemPackages = [
          (nixvim-config.lib.nixvimConfiguration {
            system = "x86_64-linux";
            userConfig = {
              myNixvim.features = {
                writing.enable = true;
              };
            };
          })
        ];
      }];
    };
  };
}
```

### Using pre-built packages

```nix
environment.systemPackages = [
  nixvim-config.packages.x86_64-linux.default    # Base config
  # nixvim-config.packages.x86_64-linux.nvim-full # All features enabled
];
```

## Structure

```
config/
├── default.nix      # Main configuration, keymaps, editor options
├── options.nix      # Feature toggles with defaults
├── core.nix         # UI plugins (bufferline, telescope, treesitter, etc.)
├── completion.nix   # nvim-cmp
├── development.nix  # LSP, lspsaga, trouble, language servers (nixd, bashls)
├── spellcheck.nix   # write-good
└── writing.nix      # vimwiki, markdown-preview, goyo
```

## Key Bindings

| Key | Action |
|-----|--------|
| `<Space>` | Leader key |
| `<C-k>` / `<C-j>` | Next / previous buffer |
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | List buffers |
| `<leader>fm` | Format buffer |
| `<F1>` | Toggle comment |
| `gd` | Go to definition |
| `gr` | Go to references |
| `K` | Hover documentation |
| `<leader>ca` | Code action |
| `<leader>cr` | Rename |
