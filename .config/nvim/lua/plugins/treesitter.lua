return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- Highlight-only support for python and sql (no LSP).
      vim.list_extend(opts.ensure_installed, { "python", "sql" })
    end,
  },
}
