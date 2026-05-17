vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

if vim.fn.executable("fish") == 1 then
  vim.opt.shell = "fish"
end

vim.opt.clipboard = "unnamedplus"
vim.opt.relativenumber = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.wrap = false
vim.opt.confirm = true
vim.opt.undofile = true
vim.opt.swapfile = false
