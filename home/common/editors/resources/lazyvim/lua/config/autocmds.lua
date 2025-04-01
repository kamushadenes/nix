-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Performance
vim.lsp.set_log_level("off")
vim.g.matchparen_timeout = 2
vim.g.matchparen_insert_timeout = 2

-- prefil edit window with common scenarios to avoid repeating query and submit immediately
local prefill_edit_window = function(request)
  require("avante.api").edit()
  local code_bufnr = vim.api.nvim_get_current_buf()
  local code_winid = vim.api.nvim_get_current_win()
  if code_bufnr == nil or code_winid == nil then
    return
  end
  vim.api.nvim_buf_set_lines(code_bufnr, 0, -1, false, { request })
  -- Optionally set the cursor position to the end of the input
  vim.api.nvim_win_set_cursor(code_winid, { 1, #request + 1 })
  -- Simulate Ctrl+S keypress to submit
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-s>", true, true, true), "v", true)
end

-- NOTE: most templates are inspired from ChatGPT.nvim -> chatgpt-actions.json
local avante_grammar_correction = "Correct the text to standard English, but keep any code blocks inside intact."
local avante_keywords = "Extract the main keywords from the following text"
local avante_code_readability_analysis = [[
  You must identify any readability issues in the code snippet.
  Some readability issues to consider:
  - Unclear naming
  - Unclear purpose
  - Redundant or obvious comments
  - Lack of comments
  - Long or complex one liners
  - Too much nesting
  - Long variable names
  - Inconsistent naming and code style.
  - Code repetition
  You may identify additional problems. The user submits a small section of code from a larger file.
  Only list lines with readability issues, in the format <line_num>|<issue and proposed solution>
  If there's no issues with code respond with only: <OK>
]]
local avante_optimize_code = "Optimize the following code"
local avante_summarize = "Summarize the following text"
local avante_explain_code = "Explain the following code"
local avante_complete_code = "Complete the following codes written in " .. vim.bo.filetype
local avante_add_docstring = "Add docstring to the following codes"
local avante_fix_bugs = "Fix the bugs inside the following codes if any"
local avante_add_tests = "Implement tests for the following code"

require("which-key").add({
  { "<leader>a", group = "Avante" }, -- NOTE: add for avante.nvim
  {
    mode = { "n", "v" },
    {
      "<leader>ag",
      function()
        require("avante.api").ask({ question = avante_grammar_correction })
      end,
      desc = "avante: grammar correction",
    },
    {
      "<leader>ak",
      function()
        require("avante.api").ask({ question = avante_keywords })
      end,
      desc = "avante: extract keywords",
    },
    {
      "<leader>al",
      function()
        require("avante.api").ask({ question = avante_code_readability_analysis })
      end,
      desc = "avante: code readability analysis",
    },
    {
      "<leader>ao",
      function()
        require("avante.api").ask({ question = avante_optimize_code })
      end,
      desc = "avante: optimize code",
    },
    {
      "<leader>am",
      function()
        require("avante.api").ask({ question = avante_summarize })
      end,
      desc = "avante: summarize text",
    },
    {
      "<leader>ax",
      function()
        require("avante.api").ask({ question = avante_explain_code })
      end,
      desc = "avante: explain code",
    },
    {
      "<leader>ac",
      function()
        require("avante.api").ask({ question = avante_complete_code })
      end,
      desc = "avante: complete code",
    },
    {
      "<leader>ad",
      function()
        require("avante.api").ask({ question = avante_add_docstring })
      end,
      desc = "avante: generate docstrings",
    },
    {
      "<leader>ab",
      function()
        require("avante.api").ask({ question = avante_fix_bugs })
      end,
      desc = "avante: fix bugs",
    },
    {
      "<leader>au",
      function()
        require("avante.api").ask({ question = avante_add_tests })
      end,
      desc = "avante: add tests",
    },
  },
})

require("which-key").add({
  { "<leader>a", group = "Avante" }, -- NOTE: add for avante.nvim
  {
    mode = { "v" },
    {
      "<leader>aG",
      function()
        prefill_edit_window(avante_grammar_correction)
      end,
      desc = "avante: grammar correction (edit)",
    },
    {
      "<leader>aO",
      function()
        prefill_edit_window(avante_optimize_code)
      end,
      desc = "avante: optimize code (edit)",
    },
    {
      "<leader>aC",
      function()
        prefill_edit_window(avante_complete_code)
      end,
      desc = "avante: complete code (edit)",
    },
    {
      "<leader>aD",
      function()
        prefill_edit_window(avante_add_docstring)
      end,
      desc = "avante: generate docstrings (edit)",
    },
    {
      "<leader>aB",
      function()
        prefill_edit_window(avante_fix_bugs)
      end,
      desc = "avante: fix bugs (edit)",
    },
    {
      "<leader>aU",
      function()
        prefill_edit_window(avante_add_tests)
      end,
      desc = "avante: add tests (edit)",
    },
  },
})
