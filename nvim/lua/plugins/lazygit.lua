return {
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader>gg",
        function()
          Snacks.lazygit({ cwd = LazyVim.root.git() })
        end,
        desc = "LazyGit (Root Dir)",
      },
      {
        "<leader>gG",
        function()
          Snacks.lazygit()
        end,
        desc = "LazyGit (cwd)",
      },
      {
        "<leader>gF",
        function()
          Snacks.lazygit.log_file()
        end,
        desc = "LazyGit Current File History",
      },
      {
        "<leader>gL",
        function()
          Snacks.lazygit.log({ cwd = LazyVim.root.git() })
        end,
        desc = "LazyGit Log (Root Dir)",
      },
    },
  },
}
