local map = vim.keymap.set

map("n", "<leader>qQ", "<cmd>qa<cr>", { desc = "Quit all" })
map("n", "<leader>uw", "<cmd>set wrap!<cr>", { desc = "Toggle word wrap" })
