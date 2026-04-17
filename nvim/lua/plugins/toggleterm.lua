return {
  "akinsho/toggleterm.nvim",
  cmd = { "ToggleTerm", "TermExec" },
  keys = {
    { "<C-\\>", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal", mode = { "n", "t" } },
    { "<leader>t1", "<cmd>1ToggleTerm direction=horizontal<cr>", desc = "Terminal 1" },
    { "<leader>t2", "<cmd>2ToggleTerm direction=horizontal<cr>", desc = "Terminal 2" },
    { "<leader>t3", "<cmd>3ToggleTerm direction=horizontal<cr>", desc = "Terminal 3" },
    { "<leader>t4", "<cmd>4ToggleTerm direction=horizontal<cr>", desc = "Terminal 4" },
    { "<leader>t5", "<cmd>5ToggleTerm direction=horizontal<cr>", desc = "Terminal 5" },
    { "<leader>t6", "<cmd>6ToggleTerm direction=horizontal<cr>", desc = "Terminal 6" },
    { "<leader>t7", "<cmd>7ToggleTerm direction=horizontal<cr>", desc = "Terminal 7" },
    { "<leader>t8", "<cmd>8ToggleTerm direction=horizontal<cr>", desc = "Terminal 8" },
    { "<leader>t9", "<cmd>9ToggleTerm direction=horizontal<cr>", desc = "Terminal 9" },
    { "<leader>ta", "<cmd>ToggleTermToggleAll<cr>", desc = "Toggle all terminals" },
    { "<leader>tf", "<cmd>ToggleTerm direction=float<cr>", desc = "Terminal (float)" },
    { "<leader>tv", "<cmd>ToggleTerm direction=vertical size=80<cr>", desc = "Terminal (vertical)" },
  },
  opts = {
    size = function(term)
      if term.direction == "horizontal" then
        return 15
      elseif term.direction == "vertical" then
        return vim.o.columns * 0.4
      end
    end,
    open_mapping = [[<c-\>]],
    shade_terminals = true,
    start_in_insert = true,
    persist_size = true,
    direction = "float",
    float_opts = {
      border = "curved",
    },
    on_open = function(term)
      local opts = { buffer = term.bufnr, silent = true }
      vim.keymap.set("t", "<esc><esc>", [[<C-\><C-n>]], opts)
      vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)
      vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
      vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
      vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
      vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
    end,
  },
}
