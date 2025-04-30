return {
  {
    "yetone/avante.nvim",
    -- version = "0.0.23",
    enabled = false,
    commit = "87ea15b",
    event = "VeryLazy",
    dependencies = {
      "stevearc/dressing.nvim",
      "ibhagwan/fzf-lua",
      "ravitemer/mcphub.nvim",
    },
    opts = {
      -- Default configuration
      hints = { enabled = false },

      ---@alias AvanteProvider "claude" | "openai" | "azure" | "gemini" | "cohere" | "copilot" | string
      provider = "claude_sonnet",
      cursor_applying_provider = "llama_3_3_70b",
      auto_suggestions_provider = "copilot", -- Since auto-suggestions are a high-frequency operation and therefore expensive, it is recommended to specify an inexpensive provider or even a free provider: copilot
      behaviour = {
        auto_suggestions = false,
        auto_apply_diff_after_generation = true,
        enable_cursor_planning_mode = true,
        embed_image_as_base64 = false,
        prompt_for_file_name = false,
        drag_and_drop = {
          insert_mode = true,
        },
        use_absolute_path = true,
      },
      web_search_engine = {
        provider = "kagi",
        api_key_name = "cmd:op item get fb7aoio7k4amhoealvjm5bvw6e --reveal --fields api_key",
      },
      vendors = {
        claude_sonnet = {
          __inherited_from = "openai",
          endpoint = "https://gateway.ai.cloudflare.com/v1/f6934f56ce237241104dbe9302cee786/hadenes/openrouter/v1",
          api_key_name = "cmd:op item get bxb4loone7wltv7nziuttxl4u4 --reveal --fields credential",
          model = "anthropic/claude-3.7-sonnet",
        },
        openai_o1 = {
          __inherited_from = "openai",
          endpoint = "https://gateway.ai.cloudflare.com/v1/f6934f56ce237241104dbe9302cee786/hadenes/openrouter/v1",
          api_key_name = "cmd:op item get bxb4loone7wltv7nziuttxl4u4 --reveal --fields credential",
          model = "openai/o1",
        },
        openai_o3 = {
          __inherited_from = "openai",
          endpoint = "https://gateway.ai.cloudflare.com/v1/f6934f56ce237241104dbe9302cee786/hadenes/openrouter/v1",
          api_key_name = "cmd:op item get bxb4loone7wltv7nziuttxl4u4 --reveal --fields credential",
          model = "openai/o3-mini",
        },
        deepseek_v3 = {
          __inherited_from = "openai",
          endpoint = "https://gateway.ai.cloudflare.com/v1/f6934f56ce237241104dbe9302cee786/hadenes/openrouter/v1",
          api_key_name = "cmd:op item get bxb4loone7wltv7nziuttxl4u4 --reveal --fields credential",
          model = "deepseek/deepseek-chat",
        },
        deepseek_r1 = {
          __inherited_from = "openai",
          endpoint = "https://gateway.ai.cloudflare.com/v1/f6934f56ce237241104dbe9302cee786/hadenes/openrouter/v1",
          api_key_name = "cmd:op item get bxb4loone7wltv7nziuttxl4u4 --reveal --fields credential",
          model = "deepseek/deepseek-r1",
        },
        qwen_2_5_coder_32b = {
          __inherited_from = "openai",
          endpoint = "https://gateway.ai.cloudflare.com/v1/f6934f56ce237241104dbe9302cee786/hadenes/openrouter/v1",
          api_key_name = "cmd:op item get bxb4loone7wltv7nziuttxl4u4 --reveal --fields credential",
          model = "qwen/qwen-2.5-coder-32b-instruct",
        },
        qwen_2_5_72b = {
          __inherited_from = "openai",
          endpoint = "https://gateway.ai.cloudflare.com/v1/f6934f56ce237241104dbe9302cee786/hadenes/openrouter/v1",
          api_key_name = "cmd:op item get bxb4loone7wltv7nziuttxl4u4 --reveal --fields credential",
          model = "qwen/qwen-2.5-72b-instruct",
        },
        qwq_32b = {
          __inherited_from = "openai",
          endpoint = "https://gateway.ai.cloudflare.com/v1/f6934f56ce237241104dbe9302cee786/hadenes/openrouter/v1",
          api_key_name = "cmd:op item get bxb4loone7wltv7nziuttxl4u4 --reveal --fields credential",
          model = "qwen/qwq-32b",
        },
        llama_3_3_70b = {
          __inherited_from = "openai",
          endpoint = "https://gateway.ai.cloudflare.com/v1/f6934f56ce237241104dbe9302cee786/hadenes/openrouter/v1",
          api_key_name = "cmd:op item get bxb4loone7wltv7nziuttxl4u4 --reveal --fields credential",
          model = "meta-llama/llama-3.3-70b-instruct",
        },
      },

      -- File selector configuration
      --- @alias FileSelectorProvider "native" | "fzf" | "mini.pick" | "snacks" | "telescope" | string
      file_selector = {
        provider = "fzf", -- Avoid native provider issues
        provider_opts = {},
      },

      rag_service = {
        enabled = true, -- Enables the RAG service
        host_mount = "/Users/kamushadenes/Dropbox/Projects", -- Host mount path for the rag service
        provider = "ollama", -- The provider to use for RAG service (e.g. openai or ollama)
        llm_model = "", -- The LLM model to use for RAG service
        embed_model = "", -- The embedding model to use for RAG service
        -- endpoint = "https://api.openai.com/v1", -- The API endpoint for RAG service
        endpoint = "http://localhost:11434",
      },

      system_prompt = function()
        local hub = require("mcphub").get_hub_instance()
        return hub:get_active_servers_prompt()
      end,
      custom_tools = function()
        return {
          require("mcphub.extensions.avante").mcp_tool(),
        }
      end,
      --disabled_tools = {
      --  "list_files",
      --  "search_files",
      --  "read_file",
      --  "create_file",
      --  "rename_file",
      --  "delete_file",
      --  "create_dir",
      --  "rename_dir",
      --  "delete_dir",
      --  "bash",
      --},
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
    -- Make sure to set this up properly if you have lazy=true
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      file_types = { "markdown", "Avante" },
    },
    ft = { "markdown", "Avante" },
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
