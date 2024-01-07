local M = {}

local bufs = {}
local wins = {}

--- Removes window from list of windows buffer is in
---@param winid number
---@param bufnr number
local function remove_win(winid, bufnr)
  if bufs[bufnr] ~= nil then
    bufs[bufnr][winid] = nil
    if vim.tbl_count(bufs[bufnr]) == 0 then
      bufs[bufnr] = nil
    end
  end
end

--- Adds window to list of windows buffer is in
---@param winid number
---@param bufnr number
local function push_win(winid, bufnr)
  if bufs[bufnr] == nil then
    bufs[bufnr] = {}
  end
  bufs[bufnr][winid] = true
end

--- Removes buffer from list of buffers in window
---@param winid number
---@param bufnr number
local function remove_buf(winid, bufnr)
  if wins[winid] == nil then
    return
  end
  if wins[winid].bufs[bufnr] == nil then
    return
  end

  local buf = wins[winid].bufs[bufnr]
  if buf == wins[winid].root then
    wins[winid].root = buf.prev
  end

  if buf.prev ~= nil then
    buf.prev.next = buf.next
  end
  if buf.next ~= nil then
    buf.next.prev = buf.prev
  end

  wins[winid].bufs[bufnr] = nil
end

--- Removes buffer and sync its list of windows
---@param winid number
---@param bufnr number
local remove_buf_and_sync = function(winid, bufnr)
  -- Check if buffer is managed
  if wins[winid] == nil then
    return
  end
  if wins[winid].bufs[bufnr] == nil then
    return
  end

  remove_buf(winid, bufnr)
  remove_win(winid, bufnr)
end

--- Adds buffer to list of buffers in window
---@param winid number
---@param bufnr number
local function push_buf(winid, bufnr)
  -- Delete `WindowLanding` buffer if it exists since replaced by `bufnr` buffer
  if wins[winid] == nil then
    -- New window
    wins[winid] = {
      root = nil,
      bufs = {},
    }
  else
    remove_buf(winid, bufnr)
  end

  -- Create new root node
  local root = {
    prev = wins[winid].root,
    next = nil,
    nr = bufnr,
  }
  if wins[winid].root ~= nil then
    wins[winid].root.next = root
  end
  wins[winid].root = root

  -- Assign new node to buffer
  wins[winid].bufs[bufnr] = root
end

--- Adds buffer and sync its list of windows
---@param winid number
---@param bufnr number
local push_buf_and_sync = function(winid, bufnr)
  push_buf(winid, bufnr)
  push_win(winid, bufnr)
end

---@type number?
local landing_bufnr = nil

--- Creates landing buffer and readds to window when needed
---@param winid number?
local load_landing_buf = function(winid)
  winid = winid or vim.fn.win_getid()
  if landing_bufnr == nil then
    landing_bufnr = vim.api.nvim_create_buf(true, true)

    -- Critical
    vim.api.nvim_set_option_value("buftype", "nofile", {
      buf = landing_bufnr,
    })
    vim.api.nvim_buf_set_text(
      landing_bufnr,
      0,
      0,
      0,
      0,
      { "No buffers open in window." }
    )
    vim.api.nvim_buf_set_name(landing_bufnr, "window://landing")
    vim.api.nvim_set_option_value("readonly", true, { buf = landing_bufnr })
    vim.api.nvim_set_option_value("modifiable", false, { buf = landing_bufnr })
    vim.api.nvim_set_option_value("modified", false, { buf = landing_bufnr })

    -- Details
    vim.api.nvim_set_option_value("filetype", "WindowLanding", {
      buf = landing_bufnr,
    })
    vim.api.nvim_set_option_value("buflisted", false, { buf = landing_bufnr })
    vim.api.nvim_win_set_buf(winid, landing_bufnr)
    vim.api.nvim_set_option_value("number", false, { scope = "local" })
    vim.api.nvim_set_option_value("relativenumber", false, { scope = "local" })
  else
    vim.api.nvim_win_set_buf(winid, landing_bufnr)
  end
end

--- Setup
M.setup = function()
  -- Allow hidden buffers (required)
  vim.o.hidden = true

  -- Buffer open autcmd in neovim lua
  local augroup = vim.api.nvim_create_augroup("WindowPlugin", {})

  vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
    group = augroup,
    callback = function()
      local winid = vim.fn.win_getid()
      if vim.fn.win_gettype(winid) == "" then
        local bufnr = tonumber(vim.fn.expand("<abuf>")) --[[@as number]]
        push_buf_and_sync(winid, bufnr)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "WinNew" }, {
    group = augroup,
    callback = function()
      local winid = vim.fn.win_getid()
      if vim.fn.win_gettype(winid) == "" then
        local bufnr = tonumber(vim.fn.expand("<abuf>")) --[[@as number]]
        push_buf_and_sync(winid, bufnr)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "WinClosed" }, {
    group = augroup,
    callback = function()
      local winid = tonumber(vim.fn.expand("<amatch>")) --[[@as number]]
      if wins[winid] ~= nil then
        for _, buf in pairs(wins[winid].bufs) do
          remove_win(winid, buf.nr)
        end
        wins[winid] = nil
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufUnload" }, {
    group = augroup,
    callback = function()
      local winid = vim.fn.win_getid()
      if vim.fn.win_gettype(winid) == "" then
        local bufnr = tonumber(vim.fn.expand("<abuf>")) --[[@as number]]
        remove_buf_and_sync(winid, bufnr)
      end
    end,
  })
end

--- Inspects internal state and prints
M.inspect = function()
  print(vim.inspect(bufs))
  print(vim.inspect(wins))
  print(
    vim.inspect(
      vim.api.nvim_cmd({ cmd = "ls", bang = true }, { output = true })
    )
  )
end

--- Splits current window while maintaining layout
---@param given_opts table?
M.split_win = vim.schedule_wrap(function(given_opts)
  local method_opts = vim.tbl_extend("keep", given_opts or {}, {
    orientation = "h",
    keep_focus = false,
    default_buffer = function()
      load_landing_buf()
    end,
  })

  local winid = vim.fn.win_getid()
  local type = "split"
  if method_opts.orientation == "v" then
    type = "vsplit"
  end
  vim.cmd("rightbelow " .. type)
  local split_winid = vim.fn.win_getid()
  vim.api.nvim_win_call(split_winid, function()
    local bufnr = vim.api.nvim_get_current_buf()
    if method_opts.default_buffer then
      method_opts.default_buffer(split_winid)
      remove_buf_and_sync(split_winid, bufnr)
    end
  end)
  if method_opts.keep_focus then
    vim.fn.win_gotoid(winid)
  end
end)

--- Closes current buffer
---@param given_opts table?
M.close_buf = vim.schedule_wrap(function(given_opts)
  local method_opts = vim.tbl_extend("keep", given_opts or {}, {
    target = {
      buffer = vim.api.nvim_get_current_buf(),
      window = vim.fn.win_getid(),
    },
    close_window = true,
  })

  local bufnr = method_opts.target.buffer
  local winid = method_opts.target.window
  local landing_buf = vim.api.nvim_get_option_value("filetype", {
    buf = bufnr,
  }) == "WindowLanding"
  local deleting = wins[winid].bufs[bufnr] == nil
    or vim.tbl_count(bufs[bufnr]) == 1
  if
    not deleting
    or not vim.api.nvim_get_option_value("modified", { buf = bufnr })
    or vim.fn.confirm(
        string.format(
          "Buffer %d has unsaved changes. Close forcefully and discard?",
          bufnr
        ),
        "&Yes\n&No",
        2,
        "Question"
      )
      == 1
  then
    remove_buf_and_sync(winid, bufnr)
    if vim.tbl_count(wins[winid].bufs) == 0 then
      if method_opts.close_window and #vim.api.nvim_list_wins() > 1 then
        -- Close window
        vim.api.nvim_win_call(winid, function()
          vim.cmd.close({ bang = true })
        end)
      else
        -- Either `opts.close_window` is false or there is only one window
        load_landing_buf(winid)
      end
    else
      vim.api.nvim_win_set_buf(winid, wins[winid].root.nr)
    end
    if deleting and not landing_buf then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
end)

return M
