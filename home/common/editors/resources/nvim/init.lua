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

-- Only trigger firenvim manually with C-e
if vim.g.started_by_firenvim == true then
  vim.g.firenvim_config.localSettings['.*'] = { takeover = 'never' }

  vim.api.nvim_create_autocmd({'BufEnter'}, {
    pattern = "github.com_*.txt",
    command = "set filetype=markdown"
  })
end
