return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- Highlight-only support for python and sql (no LSP).
      vim.list_extend(opts.ensure_installed, { "python", "sql" })
    end,
  },
  {
    "RRethy/nvim-treesitter-endwise",
    event = "InsertEnter",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("nvim-treesitter.configs").setup({ endwise = { enable = true } })
    end,
  },
}
