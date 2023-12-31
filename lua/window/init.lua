local M = {}

local opts = {}

local bufs = {}
local wins = {}

---Remove window from list of windows buffer is in
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

---Add window to list of windows buffer is in
---@param winid number
---@param bufnr number
local function push_win(winid, bufnr)
  if bufs[bufnr] == nil then
    bufs[bufnr] = {}
  end
  bufs[bufnr][winid] = true
end

---Remove buffer from list of buffers in window
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
  wins[winid].bufs[bufnr] = nil
  if buf == wins[winid].root then
    wins[winid].root = buf.prev
  end

  if buf.prev ~= nil then
    buf.prev.next = buf.next
  end
  if buf.next ~= nil then
    buf.next.prev = buf.prev
  end
end

---Remove buffer and sync its list of windows
---@param winid number
---@param bufnr number
local function remove_buf_and_sync(winid, bufnr)
  if wins[winid] == nil then
    return
  end
  if wins[winid].bufs[bufnr] == nil then
    return
  end

  remove_buf(winid, bufnr)
  remove_win(winid, bufnr)
end

---Add buffer to list of buffers in window
---@param winid number
---@param bufnr number
local function push_buf(winid, bufnr)
  if wins[winid] == nil then
    wins[winid] = {
      root = nil,
      bufs = {},
    }
  else
    remove_buf(winid, bufnr)
  end
  local window = wins[winid]

  -- Create new root node
  local root = {
    prev = window.root,
    next = nil,
    nr = bufnr,
  }
  if window.root ~= nil then
    window.root.next = root
  end
  window.root = root

  -- Assign new node to buffer
  window.bufs[bufnr] = root
end

---Add buffer and sync its list of windows
---@param winid number
---@param bufnr number
local function push_buf_and_sync(winid, bufnr)
  if not vim.api.nvim_buf_get_option(bufnr, "buflisted") then
    return
  end

  push_buf(winid, bufnr)
  push_win(winid, bufnr)
end

---Setup
---@param given_opts table?
M.setup = function(given_opts)
  -- Set `opts`
  opts = vim.tbl_extend("keep", given_opts, opts)

  -- Allow hidden buffers
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

--- Inspect internal state
M.inspect = function()
  print(vim.inspect(bufs))
  print(vim.inspect(wins))
  print(
    vim.inspect(
      vim.api.nvim_cmd({ cmd = "ls", bang = true }, { output = true })
    )
  )
end

--- Close buffer
M.close_buf = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.fn.win_getid()

  if
    not vim.api.nvim_get_option_value("modified", { buf = bufnr })
    or vim.fn.confirm(
        string.format("Buffer %d has unsaved changes. Close forcefully?", bufnr),
        "&Yes\n&No",
        2,
        "Question"
      )
      == 1
  then
    remove_buf_and_sync(winid, bufnr)
    if vim.tbl_count(wins[winid].bufs) == 0 then
      local new_bufnr = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_text(
        new_bufnr,
        0,
        0,
        0,
        0,
        { "No buffers open in window." }
      )
      vim.api.nvim_set_option_value("modifiable", false, { buf = new_bufnr })
      vim.api.nvim_set_option_value("buftype", "nofile", {
        buf = new_bufnr,
      })
      vim.api.nvim_win_set_buf(winid, new_bufnr)
      vim.api.nvim_set_option_value("number", false, { scope = "local" })
      vim.api.nvim_set_option_value(
        "relativenumber",
        false,
        { scope = "local" }
      )
    else
      vim.api.nvim_win_set_buf(winid, wins[winid].root.nr)
    end
    if bufs[bufnr] == nil then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
end

return M
