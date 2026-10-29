return {
  { "folke/tokyonight.nvim",
    init = function()
      vim.opt.number = @@editor_numbers@@
      vim.opt.signcolumn = "@@editor_signcolumn@@"
      vim.opt.foldcolumn = "@@editor_foldcolumn@@"
      vim.opt.laststatus = @@editor_statusline@@
      vim.opt.colorcolumn = "@@editor_colorcolumn@@"
      vim.opt.relativenumber = @@editor_relative_numbers@@
      vim.opt.cursorline = @@editor_cursorline@@
      vim.opt.scrolloff = @@editor_scrolloff@@
      vim.opt.wrap = @@editor_wrap@@
      vim.opt.smoothscroll = false  -- no "<<<" marker on partly scrolled wrapped lines
      vim.opt.winborder = "@@border_style@@" == "square" and "single" or "rounded"
      -- LazyVim turns spell on for prose; the squiggles read as noise across a themed editor
      -- LazyVim turns spell on in its own autocmd group, which runs after ours: remove that group once loaded
      vim.api.nvim_create_autocmd("User", { pattern = "LazyVimAutocmds",
        callback = function() pcall(vim.api.nvim_del_augroup_by_name, "lazyvim_wrap_spell") end })
      vim.api.nvim_create_autocmd("FileType", { pattern = { "markdown", "text", "gitcommit" },
        callback = function() vim.opt_local.spell = false end })
    end,
    opts = {
      style = "night",
      -- Every tokyonight color comes from the theme palette (veil-theme recolors these hexes),
      -- so syntax, gutters and the statusline change with the environment, not just the background.
      on_colors = function(c)
        c.bg = "#090d17"; c.bg_dark = "#070a12"; c.bg_float = "#0e1524"; c.bg_popup = "#0e1524"
        c.bg_sidebar = "#070a12"; c.bg_statusline = "#070a12"; c.bg_highlight = "#151b2d"
        c.bg_visual = "#26385a"; c.bg_search = "#26385a"
        c.fg = "#d9f4ff"; c.fg_dark = "#8794ad"; c.fg_sidebar = "#8794ad"; c.fg_float = "#d9f4ff"
        c.fg_gutter = "#334563"; c.comment = "#76849c"; c.dark3 = "#334563"; c.dark5 = "#76849c"
        c.terminal_black = "#26324a"; c.black = "#070a12"
        c.border = "#26324a"; c.border_highlight = "#00e5ff"
        c.blue = "#57a6ff"; c.blue0 = "#26385a"; c.blue1 = "#00e5ff"; c.blue2 = "#80f3ff"
        c.blue5 = "#93c6ff"; c.blue6 = "#80f3ff"; c.blue7 = "#182e3d"
        c.cyan = "#00e5ff"; c.teal = "#80f3ff"
        c.magenta = "#ff4fbc"; c.magenta2 = "#ff8ed4"; c.purple = "#ff8ed4"
        c.yellow = "#fcee09"; c.orange = "#fff680"
        c.green = "#5af7a5"; c.green1 = "#80f3ff"; c.green2 = "#8affbf"
        c.red = "#ff5370"; c.red1 = "#ff7890"
      end,
      on_highlights = function(hl, c)
        -- quiet code spans: tinted text, no slab background
        hl["@markup.raw.markdown_inline"] = { fg = c.cyan }
        hl["@markup.raw"] = { fg = c.cyan }
        hl["@markup.heading.1.markdown"] = { fg = c.yellow, bold = true }
        hl["@markup.heading.2.markdown"] = { fg = c.cyan, bold = true }
        hl["@markup.heading.3.markdown"] = { fg = c.magenta, bold = true }
        hl.RenderMarkdownCode = { bg = c.bg_dark }
        hl.RenderMarkdownCodeInline = { fg = c.cyan, bg = "NONE" }
        hl.SpellBad = { sp = c.comment, undercurl = true }
        hl.SpellCap = { sp = c.comment, undercurl = true }
      end,
  } },
  { "LazyVim/LazyVim", opts = { colorscheme = "tokyonight" } },
  -- statusline mode pill in the environment's accent instead of tokyonight's blue
  { "nvim-lualine/lualine.nvim", optional = true,
    opts = function(_, opts)
      local t = vim.deepcopy(require("lualine.themes.tokyonight"))
      t.normal.a.bg = "#00e5ff"; t.normal.b.fg = "#00e5ff"
      opts.options = opts.options or {}; opts.options.theme = t
    end },
}
