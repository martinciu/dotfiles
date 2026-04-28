return {
  -- Solarized theme (Solarized everywhere — dotfiles convention).
  {
    "maxmx03/solarized.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      -- maxmx03/solarized.nvim's API takes a table here, not a bool.
      transparent = {
        enabled = false,
      },
      styles = {
        comments = { italic = true },
        functions = {},
        keywords = { italic = true },
        variables = {},
      },
    },
    config = function(_, opts)
      require("solarized").setup(opts)
      vim.cmd.colorscheme("solarized")
    end,
  },
  -- Tell LazyVim to default to solarized instead of tokyonight.
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "solarized" },
  },
}
