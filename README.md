# window.nvim

Closing a file shifts window layouts? The file disappears from all windows? What's the next buffer that'll appear? Make windows intuitive again. 

## Features

On setup, the plugin mandates the use of hidden buffers. In Vim, buffers can either be hidden or not. However, for some buffers, we don't always logically want deletion to affect their presence in other windows,especially in split layouts. Furthermore, we don't want to see buffers opened in one window to randomly appear in another window when cleaning up visible buffers.

The plugin implements the concept of closing a buffer, which encompasses both deleting (wiping) and hiding buffers in an intuitive way. Each window has its own history of buffers that it manages, so only the expected buffers. 

- If closing a buffer, the previously used buffer in that window will be shown. If there are no previous buffers, a blank plugin buffer is shown.
- Windows won't close on buffer closures. You must manually command a window to close.
- Use `split_win` to split while maintaining original window layout and focus
- This works with whatever plugin you use to navigate buffers.

## Installation

You can use any plugin manager. Below is an example with `lazy.nvim` along with helpful keymaps.

```lua
{
    "dseum/window.nvim",
    dev = true,
    lazy = false,
    priority = 100,
    opts = {
      -- Closing last managed buffer should close window 
      close_window = true
    },
    keys = {
      {
        "<leader>ww",
        function()
          require("window").close_buf()
        end,
      },
      {
        "<leader>wi",
        function()
          require("window").inspect()
        end,
      },
      {
        "<C-w>s",
        function()
          require("window").split_win("h")
        end,
      },
      {
        "<C-w>v",
        function()
          require("window").split_win("v")
        end,
      },
    },
  }
```

## Similar

- [echasnovski/mini.bufremove](https://github.com/echasnovski/mini.bufremove)
