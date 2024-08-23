require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

map("v", "J", ":m '>+1<CR>gv=gv")
map("v", "K", ":m '<-2<CR>gv=gv")

map("n", "<C-l>", "<Cmd>TmuxNavigateRight<CR>")
map("n", "<c-h>", "<cmd>TmuxNavigateLeft<CR>")
map("n", "<c-j>", "<cmd>tmuxnavigatedown<cr>") 
map("n", "<c-k>", "<cmd>TmuxNavigateUp<cr>" )

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>"
-- keys = {
--     { "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
--     { "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
--     { "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
--     { "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
--     { "<c-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
