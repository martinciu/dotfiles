-- obsidian.nvim (community fork) — vault powers inside nvim: wikilink
-- completion/follow, backlinks, note/tag pickers. Vault-gated: registered
-- only when the vault exists, loads only for files inside it; markdown
-- elsewhere stays plain. render-markdown.nvim owns in-buffer rendering
-- (the fork's ui module is deprecated in favor of render plugins).
local vault = vim.fn.expand("~/code/notes")
if vim.fn.isdirectory(vault) == 0 then
  return {}
end

return {
  "obsidian-nvim/obsidian.nvim",
  version = "*", -- latest release, not tip
  event = {
    "BufReadPre " .. vault .. "/**.md",
    "BufNewFile " .. vault .. "/**.md",
  },
  init = function()
    -- Buffer-local <leader>o maps, created only on entering a vault note.
    -- Registered in init (not config) so the first note entry can't race
    -- the autocmd; a lazy-spec `keys` table would create global maps.
    vim.api.nvim_create_autocmd("User", {
      pattern = "ObsidianNoteEnter",
      callback = function(ev)
        local function map(lhs, cmd, desc)
          vim.keymap.set("n", lhs, "<cmd>Obsidian " .. cmd .. "<cr>", { buffer = ev.buf, desc = desc })
        end
        map("<leader>oo", "open", "Open in Obsidian app")
        map("<leader>of", "quick_switch", "Find note")
        map("<leader>os", "search", "Search notes")
        map("<leader>ob", "backlinks", "Backlinks")
        map("<leader>ot", "tags", "Tags")
        map("<leader>on", "new", "New note")
        local ok, wk = pcall(require, "which-key")
        if ok then
          wk.add({ { "<leader>o", group = "obsidian", buffer = ev.buf } })
        end
      end,
    })
  end,
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    legacy_commands = false, -- `:Obsidian <subcommand>` only
    workspaces = {
      { name = "notes", path = vault },
    },
    templates = { folder = "Templates" }, -- mirrors the app's setting
    ui = { enable = false }, -- render-markdown.nvim renders; avoid double UI
  },
}
