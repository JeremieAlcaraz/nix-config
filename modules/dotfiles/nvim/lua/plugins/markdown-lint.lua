return {
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}

      -- Keep markdown tooling from LazyVim extras, but disable markdownlint diagnostics.
      opts.linters_by_ft.markdown = {}
      opts.linters_by_ft["markdown.mdx"] = {}
      opts.linters_by_ft.mdx = {}
    end,
  },
}
