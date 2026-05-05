-- Block schemastore catalog injection for jsonls and yamlls. LazyVim's
-- lang.json and lang.yaml extras populate `settings.{json,yaml}.schemas`
-- with the full schemastore.org catalog (~700 fileMatch → URL pairs) via
-- a `before_init` hook. Each match triggers an HTTP fetch on first
-- validation — fine when offline-tolerant, but a freeze risk on flaky
-- networks and unwanted noise on every `:LspOn jsonls` for ad-hoc work.
--
-- Override `before_init` with a no-op so the schemas array stays empty.
-- Inline `$schema` URLs still resolve normally; per-project always-on
-- with full catalog stays available via `.nvim.lua` that overrides
-- `before_init` back to LazyVim's injector.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        jsonls = {
          before_init = function() end,
        },
        yamlls = {
          before_init = function() end,
        },
      },
    },
  },
}
