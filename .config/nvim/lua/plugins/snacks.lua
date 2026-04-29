return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          explorer = {
            hidden = true,
            ignored = true,
            exclude = { ".claude/worktrees" },
          },
          files = { exclude = { ".claude/worktrees" } },
          grep = { exclude = { ".claude/worktrees" } },
          recent = {
            filter = {
              filter = function(item)
                return not (item.file and item.file:find("/%.claude/worktrees/"))
              end,
            },
          },
        },
      },
    },
  },
  { "nvim-neo-tree/neo-tree.nvim", enabled = false },
}
