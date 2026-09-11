# NixVim Configuration

A modular Neovim configuration built with NixVim.

## Quick Start

```bash
# Run default configuration
nix run github:jtraue/nixvim

# Enter a dev shell with the wiki helper scripts on PATH
nix develop
```

## Features

| Feature | Default | Description |
|---------|---------|-------------|
| `completion.enable` | true | Autocompletion (nvim-cmp) |
| `spellcheck.enable` | true | Grammar checking (write-good) |
| `development.enable` | true | LSP, lspsaga, trouble |
| `development.nix.enable` | true | Nix support (nixd, statix, nixpkgs-fmt) |
| `development.bash.enable` | true | Bash support (bashls) |
| `writing.enable` | true | Writing tools (vimwiki, render-markdown, zen-mode, twilight) |

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
                development.bash.enable = false;
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
  nixvim-config.packages.x86_64-linux.default
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
└── writing.nix      # vimwiki, render-markdown, zen-mode, twilight

scripts/
├── wiki_link_check.py  # orphan/broken-link checker for the wiki
└── wiki_reorg.py       # move wiki files/folders and rewrite links to match
```

## Wiki Helper Scripts

Packaged as flake outputs (`wiki-link-check`, `wiki-reorg`) and available on `PATH`
inside `nix develop`. Both run entirely locally and only ever print file paths and
link text - never note bodies.

```bash
nix develop

# Report orphan pages and broken [[...]] / [text](target) links
wiki-link-check ~/cloud/home/wiki/notes

# Dry-run a folder reorganization from a plain-text moves file
# (one entry per line: "Old/Path.wiki -> New/Path.wiki" or "Old/Dir/ -> New/Dir/")
wiki-reorg ~/cloud/home/wiki/notes --moves-file moves.txt

# Actually perform the moves and rewrite links to match (uses `git mv` if the
# wiki is a git repo)
wiki-reorg ~/cloud/home/wiki/notes --moves-file moves.txt --apply
```

Without `nix develop`, use `nix run .#wiki-link-check -- <args>` / `nix run .#wiki-reorg -- <args>`
(the `--` is required so `nix run` doesn't try to parse the script's own flags).

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
| `<leader>zz` | Toggle zen mode (writing) |
