# notes.nvim

A quick-notes manager for Neovim, inspired by GNOME note apps like
[Folio](https://github.com/toolstack/Folio): **notebooks** on the left, a
**note list** (title + date) in the middle and the **editor** on the right.

Notes are plain Markdown files, so you can version them with git, sync them with
Syncthing or open them with any other editor.

<!-- TODO: add a screenshot, e.g. docs/screenshot.png -->

## Features

- Three-pane layout in a centered floating window (notebooks | notes | editor)
- Autosave, and no empty notes are ever created
- Notebooks are just directories
- Full-text search across all notebooks
- Trash with restore / permanent delete
- Quick capture: `:QuickNote` opens a new note ready to type
- Optional **popup mode**: runs in its own small terminal window, floating over
  everything else on your desktop (see [Popup mode](#popup-mode))
- No dependencies

## Requirements

- Neovim **0.9+**

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "YOUR_USER/notes.nvim",
  cmd = { "Notes", "QuickNote", "NotesApp" },
  keys = {
    { "<leader>on", "<cmd>Notes<cr>",     desc = "Open notes" },
    { "<leader>oq", "<cmd>QuickNote<cr>", desc = "Quick note" },
  },
  opts = {
    dir = "~/notes",
  },
}
```

Or, without a plugin manager, copy `lua/notes/init.lua` to
`~/.config/nvim/lua/notes/init.lua` and add to your `init.lua`:

```lua
require("notes").setup({ dir = "~/notes" })
```

## Configuration

Defaults:

```lua
require("notes").setup({
  dir = "~/notes",          -- where notes live (one directory per notebook)
  default_notebook = "General",
  ext = "md",
  width = 0.6,              -- fraction of the screen (<= 1) or number of columns
  height = 0.6,             -- fraction of the screen (<= 1) or number of lines
  books_width = 16,         -- max width of the notebooks pane
  list_width = 32,          -- max width of the note list pane
  border_hl = "Special",    -- highlight group for the window border and title
})
```

## Usage

| Command       | Description                                                        |
| ------------- | ------------------------------------------------------------------ |
| `:Notes`      | Toggle the floating notes window                                   |
| `:QuickNote`  | Open the window and start a new note in insert mode                |
| `:NotesApp`   | Fill the whole terminal window; closing quits Neovim (popup mode)  |

Keys inside the window:

| Key                 | Where              | Action                                          |
| ------------------- | ------------------ | ----------------------------------------------- |
| `<Tab>` / `<S-Tab>` | notebooks, list    | Move between panes (notebooks → list → editor)  |
| `<S-Tab>`           | editor (normal)    | Back to the note list                           |
| `<CR>`              | notebooks, list    | Open the notebook / note                        |
| `j` / `k`           | list               | Next / previous note                            |
| `n`                 | notebooks, list    | New note                                        |
| `a`                 | notebooks          | New notebook                                    |
| `/`                 | list               | Search in all notes (`<Esc>` clears)            |
| `d`                 | list               | Move to trash (permanent delete if in trash)    |
| `r`                 | list               | Restore from trash                              |
| `q`                 | notebooks, list    | Close                                           |

## Where are my notes?

```
~/notes/
├── General/                 default notebook
│   └── 20261007-173619.md   one Markdown file per note
├── Work/                    any notebook you create with `a`
└── .trash/                  the trash
```

A note's title is the first non-empty line of the file (leading `#` removed).

## Popup mode

Neovim can only draw inside its own terminal, so to get a window floating in the
middle of your *whole screen* (like a regular desktop notes app) run it in a
dedicated terminal window:

```bash
nvim +NotesApp
```

`bin/notes-popup` does that for you: it launches a small terminal window with the
class/app-id `notes-popup`. It supports kitty, ghostty, alacritty, wezterm, foot
and gnome-terminal (`TERMINAL=wezterm notes-popup` to force one,
`COLS=110 ROWS=30 notes-popup` to resize).

```bash
install -Dm755 bin/notes-popup ~/.local/bin/notes-popup
```

Then ask your window manager to float and center that class. Examples for
Hyprland are in [`examples/`](examples/). For sway / i3:

```
# sway
for_window [app_id="notes-popup"] floating enable, move position center
# i3
for_window [class="notes-popup"] floating enable, move position center
```

On GNOME, new windows are already floating and centered; just bind
`notes-popup` to a shortcut.

> The launcher script is best-effort: only the Neovim plugin has automated
> headless tests so far. Please open an issue if your terminal misbehaves.

## License

[MIT](LICENSE)
