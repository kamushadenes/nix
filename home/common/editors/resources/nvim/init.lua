vim.g.mapleader = ","

require("catppuccin").setup({
    flavour = "auto",
     background = { -- :h background
        light = "latte",
        dark = "macchiato",
    },
})

vim.cmd.colorscheme "catppuccin"

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true

vim.opt.shiftwidth = 2

-- Make sure to access arc://extensions/shortcuts and set the Cmd+G shortcut as Global
vim.g.firenvim_config = {
    globalSettings = { alt = "all" },
    localSettings = {
        [".*"] = {
            cmdline = 'firenvim',
            takeover = "never"
        }
    }
}

vim.api.nvim_create_autocmd({'BufEnter'}, {
  pattern = "github.com_*.txt",
  command = "set filetype=markdown"
})
