# window.nvim

Deleting a buffer closes multiple windows? What's the next buffer that'll display in the window?

Make windows intuitive again.

## Features

This plugin introduces the concept of opening and closing buffers in windows.

Windows are no longer just views. Instead, each window keeps a stack of buffers that determines the next buffer to display upon closing the active buffer. Use `close_buf` instead of manually deciding between hiding/deleting/wiping out a buffer.

We should, then, also expect the newly split window to not be in the same location as the original window. To do this, use `split_win`.

## Installation

You can use any plugin manager. Below is an example with `lazy.nvim` along with helpful keymaps. Note that on `setup`, the plugin mandates the use of hidden buffers.

```lua
{
  "dseum/window.nvim",
  config = function()
    local window = require("window")
    window.setup()
    vim.keymap.set("n", "<Leader>ww", function()
      window.close_buf()
    end)
    vim.keymap.set("n", "<C-w>s", function()
      window.split_win({
        default_buffer = false,
      })
    end)
    vim.keymap.set("n", "<C-w>v", function()
      window.split_win({
        orientation = "v",
        default_buffer = false,
      })
    end)
  end
}
```

## Configuration

`setup` has no configuration.

### `close_buf`

| Property     | Type       | Description                                                                          |
| ------------ | ---------- | ------------------------------------------------------------------------------------ |
| close_window | `boolean?` | Whether closing last buffer in window closes the window or loads the landing buffer. |

### `split_win`

| Property       | Type                                  | Description                                                                                            |
| -------------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| orientation    | `"h"` or `"v"`                        | Horizontal or vertical.                                                                                |
| default_buffer | `false` or `fun(split_winid: number)` | Default opens a landing buffer while `false` is Neovim's default. The callback loads a desired buffer. |

## Similar

- [echasnovski/mini.bufremove](https://github.com/echasnovski/mini.bufremove)
