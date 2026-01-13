-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
-- lua/keymaps.lua
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

----------------
-- Normal Mode
----------------

-- move
map("n", "a", "b", opts)   -- previous word
map("n", "d", "w", opts)   -- next word
map("n", "s", "0", opts)   -- line start
map("n", "w", "$", opts)   -- line end
map("n", "e", "e", opts)   -- end of word
map("n", "q", "^", opts)   -- first non-blank
-- gg and G are already defaults; keep as-is (no mapping needed)

-- delete (x-prefixed)
map("n", "xr", "dd", opts) -- delete line
map("n", "xx", "dw", opts) -- delete word
map("n", "xn", "d$", opts) -- delete to end of line

-- copy
vim.keymap.set("n", "c", "<nop>", { noremap = true, silent = true })
map("n", "cr", "yy", opts) -- yank line
map("n", "cc", "yw", opts) -- yank word
map("n", "cn", "y$", opts) -- yank to end of line

-- paste
map("n", "p", "p", opts)
map("n", "P", "P", opts)

-- undo/redo
map("n", "u", "u", opts)
map("n", "y", "<C-r>", opts)

-- viewport
vim.keymap.set("n", "v", "<nop>", { noremap = true, silent = true })
map("n", "vv", "zz", opts) -- center cursor line
map("n", "vt", "zt", opts) -- cursor line to top
map("n", "vc", "zz", opts) -- cursor line to middle
map("n", "vb", "zb", opts) -- cursor line to bottom

----------------
-- Buffer / Tab (always available)
----------------
map({ "n", "i", "v" }, "<F1>", "<cmd>bprevious<cr>", opts)
map({ "n", "i", "v" }, "<F2>", "<cmd>bnext<cr>", opts)
map({ "n", "i", "v" }, "<F3>", "<cmd>tabprevious<cr>", opts)
map({ "n", "i", "v" }, "<F4>", "<cmd>tabnext<cr>", opts)

----------------
-- Insert Mode (requested)
----------------
map("n", "i", "i", opts)
map("n", "n", "o", opts)  -- new line below (enters insert)
map("n", "N", "O", opts)  -- new line above (enters insert)
