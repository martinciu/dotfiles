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
  -- Dracula (new — loaded when theme.lua resolves to dracula).
  {
    "Mofiqul/dracula.nvim",
    name = "dracula",
    lazy = false,
    priority = 1000,
    opts = {
      italic_comment = true,
    },
    config = function(_, opts)
      require("dracula").setup(opts)
      if current == "dracula" then
        vim.cmd.colorscheme("dracula")
      end
    end,
  },
  -- Gruvbox (new — loaded when theme.lua resolves to gruvbox).
  {
    "ellisonleao/gruvbox.nvim",
    name = "gruvbox",
    lazy = false,
    priority = 1000,
    opts = {
      contrast = "", -- "", "hard", "soft" — empty = medium (matches the rest of our stack)
      italic = {
        strings = false,
        comments = true,
        operators = false,
        folds = true,
      },
    },
    config = function(_, opts)
      require("gruvbox").setup(opts)
      if current == "gruvbox" then
        vim.cmd.colorscheme("gruvbox")
      end
    end,
  },
  -- Tokyo Night (new — loaded when theme.lua resolves to tokyonight-storm).
  {
    "folke/tokyonight.nvim",
    name = "tokyonight",
    lazy = false,
    priority = 1000,
    opts = {
      style = "storm",
      transparent = false,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
      },
    },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      if current == "tokyonight-storm" then
        vim.cmd.colorscheme("tokyonight-storm")
      end
    end,
  },
  -- Nord (new — loaded when theme.lua resolves to nord).
  {
    "gbprod/nord.nvim",
    name = "nord",
    lazy = false,
    priority = 1000,
    opts = {
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
      },
    },
    config = function(_, opts)
      require("nord").setup(opts)
      if current == "nord" then
        vim.cmd.colorscheme("nord")
      end
    end,
  },
  -- Tell LazyVim which colorscheme to default to (matches our resolver).
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = current },
  },
}
