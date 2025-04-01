return {
  {
    "yetone/avante.nvim",
    -- version = "0.0.23",
    enabled = false,
    commit = "cd13eeb",
    event = "VeryLazy",
    dependencies = {
      "stevearc/dressing.nvim",
      "ibhagwan/fzf-lua",
    },
    opts = {
      -- Default configuration
      hints = { enabled = false },

      ---@alias AvanteProvider "claude" | "openai" | "azure" | "gemini" | "cohere" | "copilot" | string
      provider = "openrouter_claude_sonnet",
      openai = {
        endpoint = "https://api.openai.com/v1",
        model = "o3-mini", -- your desired model (or use gpt-4o, etc.)
        api_key_name = "cmd:op item get wlg5ynxr5jzlieh5cwc2qqajyi --reveal --fields avante",
        timeout = 30000, -- Timeout in milliseconds, increase this for reasoning models
        temperature = 0,
      },
      auto_suggestions_provider = "copilot", -- Since auto-suggestions are a high-frequency operation and therefore expensive, it is recommended to specify an inexpensive provider or even a free provider: copilot
      behaviour = {
        auto_suggestions = false,
      },
      web_search_engine = {
        provider = "kagi",
        api_key_name = "cmd:op item get fb7aoio7k4amhoealvjm5bvw6e --reveal --fields api_key",
      },
      vendors = {
        openrouter_claude_sonnet = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "cmd:op item get bxb4loone7wltv7nziuttxl4u4 --reveal --fields credential",
          model = "anthropic/claude-3.7-sonnet",
        },
        openrouter_openai_o1 = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "cmd:op item get bxb4loone7wltv7nziuttxl4u4 --reveal --fields credential",
          model = "openai/o1",
        },
        openrouter_openai_o3 = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "cmd:op item get bxb4loone7wltv7nziuttxl4u4 --reveal --fields credential",
          model = "openai/o3-mini",
        },
        openrouter_deepseek_v3 = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "cmd:op item get bxb4loone7wltv7nziuttxl4u4 --reveal --fields credential",
          model = "deepseek/deepseek-chat:free",
        },
        openrouter_deepseek_r1 = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "cmd:op item get bxb4loone7wltv7nziuttxl4u4 --reveal --fields credential",
          model = "deepseek/deepseek-r1:free",
        },
        openrouter_qwen_2_5_coder_32b = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "cmd:op item get bxb4loone7wltv7nziuttxl4u4 --reveal --fields credential",
          model = "qwen/qwen-2.5-coder-32b-instruct:free",
        },
        openrouter_qwen_2_5_72b = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "cmd:op item get bxb4loone7wltv7nziuttxl4u4 --reveal --fields credential",
          model = "qwen/qwen-2.5-72b-instruct:free",
        },
        openrouter_qwq_32b = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "cmd:op item get bxb4loone7wltv7nziuttxl4u4 --reveal --fields credential",
          model = "qwen/qwq-32b:free",
        },
      },

      -- File selector configuration
      --- @alias FileSelectorProvider "native" | "fzf" | "mini.pick" | "snacks" | "telescope" | string
      file_selector = {
        provider = "fzf", -- Avoid native provider issues
        provider_opts = {},
      },
    },
    build = LazyVim.is_win() and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" or "make",
  },
  {
    "saghen/blink.cmp",
    lazy = true,
    dependencies = { "saghen/blink.compat" },
    opts = {
      sources = {
        default = { "avante_commands", "avante_mentions", "avante_files" },
        compat = {
          "avante_commands",
          "avante_mentions",
          "avante_files",
        },
        -- LSP score_offset is typically 60
        providers = {
          avante_commands = {
            name = "avante_commands",
            module = "blink.compat.source",
            score_offset = 90,
            opts = {},
          },
          avante_files = {
            name = "avante_files",
            module = "blink.compat.source",
            score_offset = 100,
            opts = {},
          },
          avante_mentions = {
            name = "avante_mentions",
            module = "blink.compat.source",
            score_offset = 1000,
            opts = {},
          },
        },
      },
    },
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    ft = function(_, ft)
      vim.list_extend(ft, { "Avante" })
    end,
    opts = function(_, opts)
      opts.file_types = vim.list_extend(opts.file_types or {}, { "Avante" })
    end,
  },
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>a", group = "ai" },
      },
    },
  },
}
