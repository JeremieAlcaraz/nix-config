return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    -- On s'assure qu'il se charge pour ces fichiers
    ft = { "markdown", "markdown.mdx", "mdx" },
    opts = {
      file_types = { "markdown", "markdown.mdx", "mdx" },
      heading = {
        enabled = true,
        -- On tente les jolies icônes. Si tu vois des carrés, on remettra "1", "2"
        icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
        sign = false, -- Retire l'icône dans la marge grise pour épurer
        position = "overlay", -- Remplace directement le #
      },
      bullet = {
        enabled = true,
        icons = { "●", "○", "◆", "◇" },
      },
      code = {
        sign = false,
        width = "block",
        right_pad = 2,
      },
    },
  },
}
