local M = {}

--
local opts = {
  close_window = true,
}

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
local function remove_buf_and_sync(winid, bufnr)
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
local function push_buf_and_sync(winid, bufnr)
  push_buf(winid, bufnr)
  push_win(winid, bufnr)
end

---@type number?
local landing_bufnr = nil

--- Creates landing buffer and readds to window when needed
---@param winid number
---@return number
local function push_landing_buf(winid)
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
  return landing_bufnr
end

--- Setup
---@param given_opts table?
M.setup = function(given_opts)
  -- Set `opts`
  opts = vim.tbl_extend("keep", given_opts, opts)

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
      local bufnr = tonumber(vim.fn.expand("<abuf>")) --[[@as number]]
      local winid = vim.fn.win_getid()
      remove_buf_and_sync(winid, bufnr)
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

--- Splits window by orientation and maintains original layout and focus
---@param orientation "h"|"v"
---@param winid number?
M.split_win = function(orientation, winid)
  winid = winid or vim.fn.win_getid()

  if orientation == "h" then
    vim.api.nvim_win_call(winid, function()
      vim.cmd("rightbelow split")
    end)
  elseif orientation == "v" then
    vim.api.nvim_win_call(winid, function()
      vim.cmd("rightbelow vsplit")
    end)
  end
  vim.fn.win_gotoid(winid)
end

--- Closes current buffer
---@param target table?
M.close_buf = vim.schedule_wrap(function(target)
  local bufnr
  local winid
  if target == nil then
    bufnr = vim.api.nvim_get_current_buf()
    winid = vim.fn.win_getid()
  else
    if target.bufnr == nil or target.winid == nil then
      return
    end
    bufnr = target.bufnr
    winid = target.winid
  end

  -- Check if buffer is managed in current window
  if wins[winid].bufs[bufnr] == nil then
    return
  end

  if
    vim.api.nvim_get_option_value("filetype", {
      buf = bufnr,
    }) ~= "WindowLanding"
  then
    local deleting = vim.tbl_count(bufs[bufnr]) == 1
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
      local closing_window = opts.close_window and #vim.api.nvim_list_wins() > 1
      if vim.tbl_count(wins[winid].bufs) == 0 then
        if closing_window then
          -- Close window
          vim.api.nvim_win_call(winid, function()
            vim.cmd.close({ bang = true })
          end)
        else
          -- Either `opts.close_window` is false or there is only one window
          push_landing_buf(winid)
        end
      else
        vim.api.nvim_win_set_buf(winid, wins[winid].root.nr)
      end
      if deleting then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end
end)

return M
