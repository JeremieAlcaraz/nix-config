local file_utils = require("utils.files")
return {
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        autokeys = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
        preset = {
          header = [[
          

          (`-')  _   (`-')  (`-')  _<-. (`-')    _      (`-')  _ 
          ( OO).-/<-.(OO )  ( OO).-/   \(OO )_  (_)     ( OO).-/ 
   <-.--.(,------.,------,)(,------.,--./  ,-.) ,-(`-')(,------. 
 (`-'| ,| |  .---'|   /`. ' |  .---'|   `.'   | | ( OO) |  .---' 
 (OO |(_|(|  '--. |  |_.' |(|  '--. |  |'.'|  | |  |  )(|  '--.  
,--. |  | |  .--' |  .   .' |  .--' |  |   |  |(|  |_/  |  .--'  
|  '-'  / |  `---.|  |\  \  |  `---.|  |   |  | |  |'-> |  `---. 
 `-----'  `------'`--' '--' `------'`--'   `--' `--'    `------']],
        },
        formats = {
          file = file_utils.format_file_for_dashboard,
        },
        sections = {
          { section = "header", gap = 0, padding = 0 },
          { icon = " ", title = "Keymaps", section = "keys", indent = 2, padding = 1, gap = 0 },
          { icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
          { icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
          { section = "startup" },
        },
      },
    },
  },
}
