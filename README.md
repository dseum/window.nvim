# window.nvim

Closing a file shifts window layouts? The file disappears from all windows? What's the next buffer that'll appear?

Make windows intuitive again. 

## Features

On setup, the plugin mandates `vim.o.hidden = true`, i.e. the use of hidden buffers. But that is not expressive enough for managing buffers.

Logically, we want our actions on buffers in a window to be locally scoped. But because windows share all buffers, deletion of a buffer in one window will mean even if we cannot expect it to still live in another window we were previously editing the buffer. Furthermore, we do not know which buffer will appear next in that window since the decision is not based off a local stack.

This plugin allows the user to forget about the nuanaces of hiding, deleting, and wiping out a buffer. Instead, all of that is cleanly managed by the plugin to provide the single concept of "closing" a buffer with `close_buf`.

- Windows keep a local stack of which buffers were previously used. You can always predict which buffer will appear next.
- You can use `split_win` to split a window while maintaining the original window layout and focus.
- This works with whatever plugin you use to navigate buffers.

## Installation

You can use any plugin manager. Below is an example with `lazy.nvim` along with helpful keymaps.

```lua
{
  "dseum/window.nvim",
  lazy = false,
  config = true,
  keys = {
    {
      "<leader>ww",
      function()
        require("window").close_buf()
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

## Configuration

The default configuration is shown below.
```lua
{
  -- Closing last managed buffer should close window
  close_window = true,
}
```

## Problems
- I use `oil.nvim`, but it creates extraneous buffers that pollute a window. Plugins that utilize buffers similarly are currently inconvenient to work with with this plugin.

## Similar

- [echasnovski/mini.bufremove](https://github.com/echasnovski/mini.bufremove)
