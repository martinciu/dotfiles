return {
  {
    "zapling/mason-lock.nvim",
    dependencies = { "mason-org/mason.nvim" },
    init = function()
      require("mason-lock").setup({
        lockfile_path = vim.fn.stdpath("config") .. "/mason-lock.json",
      })
    end,
  },
}
