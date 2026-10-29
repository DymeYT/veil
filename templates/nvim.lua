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
  -- statusline: mode pill in the environment's accent, and each environment's own form (style editor_status_layout)
  { "nvim-lualine/lualine.nvim", optional = true,
    opts = function(_, opts)
      local t = vim.deepcopy(require("lualine.themes.tokyonight"))
      t.normal.a.bg = "#00e5ff"; t.normal.b.fg = "#00e5ff"
      opts.options = opts.options or {}; opts.options.theme = t
      local none = { left = "", right = "" }
      local clock = function() return (os.date("%I:%M %p"):gsub("^0", "")) end  -- 12-hour
      local bracket = function(s) return s ~= "" and "[" .. s .. "]" or s end
      local initial = function(s) return s:sub(1, 1) end
      local kanji = { NORMAL = "常", INSERT = "入", VISUAL = "視", ["V-LINE"] = "行", ["V-BLOCK"] = "矩",
                      COMMAND = "令", REPLACE = "替", TERMINAL = "端", SELECT = "選" }
      local layouts = {
        -- hud (Night City): LazyVim's full powerline, unchanged
        directive = { comp = { left = "│", right = "│" }, sections = {  -- Arasaka: terse operations line
          lualine_a = { { "mode", fmt = string.upper } }, lualine_b = { { "filename", path = 1 } }, lualine_c = {},
          lualine_x = { "diagnostics" }, lualine_y = { "location" }, lualine_z = { clock } } },
        thread = { comp = { left = "·", right = "·" }, sections = {  -- Pharloom: one quiet thread, no blocks
          lualine_a = {}, lualine_b = {}, lualine_c = { { "mode", fmt = string.lower }, "filename", "diff" },
          lualine_x = { "filetype" }, lualine_y = {}, lualine_z = { "progress" } } },
        quiet = { sections = {  -- Hallownest: the page and where you are, nothing else
          lualine_a = {}, lualine_b = {}, lualine_c = { "filename" }, lualine_x = { "location" }, lualine_y = {}, lualine_z = {} } },
        production = { comp = { left = "┃", right = "┃" }, sections = {  -- Foundry: bracketed instrument readouts
          lualine_a = { { "mode", fmt = bracket } }, lualine_b = { { "branch", fmt = bracket }, "diff" },
          lualine_c = { { "filename", path = 1 } }, lualine_x = { "diagnostics", "filetype" },
          lualine_y = { { "progress", fmt = bracket } }, lualine_z = { { "location", fmt = bracket } } } },
        route = { comp = { left = "─●─", right = "─●─" }, sections = {  -- New York: the file as a line of stops
          lualine_a = { { "mode", fmt = initial } }, lualine_b = {}, lualine_c = { "branch", "filename", "diagnostics" },
          lualine_x = {}, lualine_y = { "progress" }, lualine_z = { "location" } } },
        field = { sections = {  -- Paradis: field report with 24-hour military time
          lualine_a = { { "mode", fmt = string.upper } }, lualine_b = { "filename" }, lualine_c = { "diagnostics" },
          lualine_x = { "filetype" }, lualine_y = {}, lualine_z = { function() return (os.date("%I:%M %p"):gsub("^0", "")) end } } },
        ink = { sections = {  -- Eclipse: mode and position only (the statusline is usually hidden)
          lualine_a = { "mode" }, lualine_b = {}, lualine_c = {}, lualine_x = {}, lualine_y = {}, lualine_z = { "location" } } },
        atlas = { comp = { left = "—", right = "—" }, sections = {  -- Guidance: a map legend, title-case mode
          lualine_a = { { "mode", fmt = function(s) return s:sub(1, 1) .. s:sub(2):lower() end } }, lualine_b = { "branch" },
          lualine_c = { { "filename", path = 1 } }, lualine_x = {}, lualine_y = {}, lualine_z = { "progress" } } },
        ember = { comp = { left = "·", right = "·" }, sections = {  -- Cinder: line of the whole, like a bonfire count
          lualine_a = { "mode" }, lualine_b = {}, lualine_c = { "filename" }, lualine_x = { "diff" }, lualine_y = {},
          lualine_z = { function() return vim.fn.line(".") .. " ⁄ " .. vim.fn.line("$") end } } },
        kanji = { sections = {  -- Ashina: the mode as a single kanji tag
          lualine_a = { { "mode", fmt = function(s) return kanji[s] or s end } }, lualine_b = { "branch" },
          lualine_c = { "filename" }, lualine_x = {}, lualine_y = {}, lualine_z = { "location" } } },
      }
      local l = layouts["@@editor_status_layout@@"]
      if l then
        opts.options.section_separators = l.sep or none
        opts.options.component_separators = l.comp or none
        if l.icons == false then opts.options.icons_enabled = false end
        opts.sections = l.sections
      end
    end },
}
