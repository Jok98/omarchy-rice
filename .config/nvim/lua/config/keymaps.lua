-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
-- lua/keymaps.lua
local map = vim.keymap.set

local opts = { noremap = true, silent = true }

----------------
-- ALT -> Normal
----------------
-- ALT alone is not a real keycode in terminals; use a Meta combo.
map({ "i", "v", "c", "t" }, "<M-/>", "<Esc>", opts)

----------------
-- Normal Mode
----------------

-- move
map("n", "a", "b", opts)   -- previous word
map("n", "d", "w", opts)   -- next word
map("n", "s", "0", opts)   -- line start
map("n", "w", "$", opts)   -- line end
map("n", "e", "e", opts)   -- end of word
map("n", "q", "^", opts)   -- first non-blank char

-- delete (x-prefixed)
map("n", "xr", "dd", opts) -- delete line
map("n", "xx", "dw", opts) -- delete word
map("n", "xn", "d$", opts) -- delete to end of line

-- copy
map("n", "cr", "yy", opts) -- yank line
map("n", "cc", "yw", opts) -- yank word
map("n", "cn", "y$", opts) -- yank to end of line

-- paste
map("n", "p", "p", opts)
map("n", "P", "P", opts)

-- undo/redo
map("n", "u", "u", opts)
map("n", "r", "<C-r>", opts)

----------------
-- Insert Mode
----------------

-- enter insert
map("n", "i", "i", opts)

-- new lines
map("n", "n", "o", opts)  -- new line below (enters insert)
map("n", "N", "O", opts)  -- new line above (enters insert)
