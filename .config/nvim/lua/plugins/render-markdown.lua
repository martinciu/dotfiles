return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "Avante" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      -- Renders headings, code blocks, checkboxes inline in the buffer.
      -- Defaults are good; opts intentionally empty to inherit them.
    },
  },
}
