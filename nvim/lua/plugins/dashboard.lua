-- Replace LazyVim default dashboard header with an anime ASCII art.
-- To swap the art: edit the `header` string below, then `:Lazy reload snacks.nvim` or restart nvim.
-- Tools for generating: https://www.asciiart.eu/anime-and-manga  |  jp2a image.jpg --width=60

local header = [[


                                ⢀⣠⣤⣤⣤⣤⣤⣤⡀
                          ⢀⣠⣴⣾⣿⣿⠿⠛⠛⠛⠻⠿⣿⣿⣷⣦⣄
                      ⣠⣾⣿⠟⠋⠁                    ⠙⠻⣿⣷⣄
                   ⣰⣿⠟⠁                              ⠈⠻⣿⣆
                 ⣰⣿⠏                                    ⠹⣿⣆
               ⣰⣿⠏              ♡  NEOVIM  ♡              ⠹⣿⡄
              ⣼⣿⠁                                          ⠈⣿⣧
              ⣿⡟                                             ⢿⣿
              ⣿⡇      ✦    ぼくの せかいへ ようこそ    ✦     ⢸⣿
              ⢹⣿⡀                                            ⢀⣿⡏
               ⠹⣿⣦⡀                                       ⢀⣴⣿⠏
                 ⠙⢿⣷⣄⡀                               ⢀⣠⣾⡿⠋
                    ⠈⠛⠿⣿⣷⣦⣤⣄⣀⣀⣀         ⣀⣀⣀⣤⣤⣶⣾⣿⠿⠛⠁
                          ⠉⠙⠛⠻⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠛⠛⠋⠉


]]

return {
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = header,
        },
      },
    },
  },
}
