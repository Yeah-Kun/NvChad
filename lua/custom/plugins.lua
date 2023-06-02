local plugins = {

  { "elkowar/yuck.vim" , lazy = true },  -- 懒加载

  -- You can use any plugin specification from lazy.nvim
  {
    "Pocco81/TrueZen.nvim",
    cmd = { "TZAtaraxis", "TZMinimalist" },
    config = function()
      require "custom.configs.truezen" -- just an example path
    end,
  },

  -- this opts will extend the default opts 
  {
      "nvim-treesitter/nvim-treesitter",
      opts = {
        ensure_installed = {
          -- defaults 
          "vim",
          "lua",

          -- web dev 
          "html",
          "css",
          "javascript",
          "typescript",
          "tsx",
          "json",
          -- "vue", "svelte",

        -- game
        "c_sharp",
        "python",

         -- low level
          "c",
          "zig"
        },
      },
    },

  -- if you load some function or module within your opt, wrap it with a function
  {
   "nvim-telescope/telescope.nvim",
   opts = {
     defaults = {
       mappings = {
         i = {
           ["<esc>"] = function(...)
               require("telescope.actions").close(...)
            end,
          },
        },
      },
    },
   },

   {
     "folke/which-key.nvim",
     enabled = false,
   },

  -- In order to modify the `lspconfig` configuration:
  {
    "neovim/nvim-lspconfig",
     config = function()
        require "plugins.configs.lspconfig"
        require "custom.configs.lspconfig"
     end,
  },
{
   "williamboman/mason.nvim",
   opts = {
      ensure_installed = {
        "lua-language-server",
        "html-lsp",
        "prettier",
        "stylua"
      },
    },
  }
}

return plugins


