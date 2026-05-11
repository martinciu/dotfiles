local theme = require("config.theme")
local current = theme.current()

return {
  -- Solarized (default, fallback). Existing plugin — unchanged spec.
  {
    "maxmx03/solarized.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      transparent = { enabled = false },
      styles = {
        comments = { italic = true },
        functions = {},
        keywords = { italic = true },
        variables = {},
      },
    },
    config = function(_, opts)
      require("solarized").setup(opts)
      if current == "solarized" then
        vim.cmd.colorscheme("solarized")
      end
    end,
  },
  -- Catppuccin (new — loaded when theme.lua resolves to catppuccin-mocha).
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha",
      styles = {
        comments = { "italic" },
        keywords = { "italic" },
      },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      if current == "catppuccin-mocha" then
        vim.cmd.colorscheme("catppuccin-mocha")
      end
    end,
  },
  -- Tell LazyVim which colorscheme to default to (matches our resolver).
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = current },
  },
}
