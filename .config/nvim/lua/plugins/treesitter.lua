return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- Highlight-only support for python and sql (no LSP).
      vim.list_extend(opts.ensure_installed, { "python", "sql" })
    end,
  },
  {
    -- endwise auto-inits via its own plugin/ file ("no configuration required").
    -- Load on the filetypes it ships endwise queries for; `ft` makes lazy.nvim
    -- re-fire FileType so the current buffer attaches immediately. Do NOT add a
    -- `config` calling nvim-treesitter.configs.setup() — that module is gone on
    -- the nvim-treesitter `main` branch and throws on InsertEnter.
    "RRethy/nvim-treesitter-endwise",
    ft = { "ruby", "lua", "bash", "fish", "vim", "elixir", "julia", "luau", "verilog" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
  },
}
