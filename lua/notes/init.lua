-- ~/.config/nvim/lua/notes/init.lua
-- Quick notes manager in a centered floating window:
--   notebooks | note list | editor
-- Requires Neovim 0.9+

local M = {}

local uv = vim.uv or vim.loop
local ns = vim.api.nvim_create_namespace("notes")
local TRASH = ".trash"

M.config = {
  dir = "~/notes",          -- where notes live (one directory per notebook)
  default_notebook = "General",
  ext = "md",
  width = 0.6,              -- window width: fraction of the screen (<=1) or columns
  height = 0.6,             -- window height: fraction of the screen (<=1) or lines
  books_width = 16,         -- max width of the notebooks pane
  list_width = 32,          -- max width of the note list pane
  border_hl = "Special",    -- highlight group used for the window border/title
}

local S = {
  closing = false, app = false, notebook = nil, query = nil, current = nil,
  notes = {}, books = {}, win = {}, buf = {},
}

-- ───────────────────────────── helpers ─────────────────────────────
local function alive(w) return w ~= nil and vim.api.nvim_win_is_valid(w) end
local function is_open() return alive(S.win.frame) end
local function nbpath(nb) return M.config.dir .. "/" .. nb end

local function read_file(file)
  local f = io.open(file, "r")
  if not f then return "" end
  local text = f:read("*a")
  f:close()
  return text or ""
end

local function title_of(text)
  local first = text:match("%S[^\n]*") or ""
  first = first:gsub("^#+%s*", "")
  first = vim.trim(first)
  return first ~= "" and first or "(untitled)"
end

local function scan(nb, query)
  local out, dir, suffix = {}, nbpath(nb), "." .. M.config.ext
  for name, t in vim.fs.dir(dir) do
    if t == "file" and name:sub(-#suffix) == suffix then
      local full = dir .. "/" .. name
      local text = read_file(full)
      if not query or text:lower():find(query:lower(), 1, true) then
        local st = uv.fs_stat(full)
        out[#out + 1] = {
          file = full, nb = nb, title = title_of(text),
          mtime = st and st.mtime.sec or 0,
        }
      end
    end
  end
  return out
end

local function notebooks()
  local res = {}
  for name, t in vim.fs.dir(M.config.dir) do
    if t == "directory" and name:sub(1, 1) ~= "." then res[#res + 1] = name end
  end
  table.sort(res)
  res[#res + 1] = TRASH
  return res
end

local function scratch()
  local b = vim.api.nvim_create_buf(false, true)
  vim.bo[b].bufhidden = "wipe"
  vim.bo[b].swapfile = false
  vim.bo[b].modifiable = false
  return b
end

local function set_lines(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

-- ───────────────────────────── render ──────────────────────────────
local function render_books()
  local lines = {}
  for _, nb in ipairs(S.books) do
    lines[#lines + 1] = " " .. (nb == TRASH and "Trash" or nb)
  end
  set_lines(S.buf.books, lines)
  vim.api.nvim_buf_clear_namespace(S.buf.books, ns, 0, -1)
  for i, nb in ipairs(S.books) do
    if nb == S.notebook and not S.query then
      vim.api.nvim_buf_set_extmark(S.buf.books, ns, i - 1, 0, { line_hl_group = "Visual" })
    end
  end
end

-- each note takes 2 lines: title and date
local function render_list(follow)
  local buf, maxw = S.buf.list, M.config.list_width - 3
  local lines = {}
  for _, n in ipairs(S.notes) do
    lines[#lines + 1] = " " .. vim.fn.strcharpart(n.title, 0, maxw)
    lines[#lines + 1] = " " .. os.date("%d %b, %H:%M", n.mtime)
      .. (S.query and ("  · " .. n.nb) or "")
  end
  if #lines == 0 then
    lines = { " (empty — press n)", " " }
  end
  set_lines(buf, lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for i, n in ipairs(S.notes) do
    local r = (i - 1) * 2
    vim.api.nvim_buf_set_extmark(buf, ns, r, 0, { end_col = #lines[r + 1], hl_group = "Title" })
    vim.api.nvim_buf_set_extmark(buf, ns, r + 1, 0, { end_col = #lines[r + 2], hl_group = "Comment" })
    if n.file == S.current then
      vim.api.nvim_buf_set_extmark(buf, ns, r, 0, { line_hl_group = "Visual" })
      vim.api.nvim_buf_set_extmark(buf, ns, r + 1, 0, { line_hl_group = "Visual" })
      if follow and alive(S.win.list) then
        pcall(vim.api.nvim_win_set_cursor, S.win.list, { r + 1, 0 })
      end
    end
  end
end

local function refresh(follow)
  if not is_open() then return end
  S.books = notebooks()
  local notes = {}
  if S.query then
    for _, nb in ipairs(S.books) do
      if nb ~= TRASH then vim.list_extend(notes, scan(nb, S.query)) end
    end
  else
    notes = scan(S.notebook)
  end
  table.sort(notes, function(a, b) return a.mtime > b.mtime end)
  S.notes = notes
  render_books()
  render_list(follow)
end

-- ───────────────────────────── actions ───────────────────────────────
local function current_note()
  if not alive(S.win.list) then return nil end
  return S.notes[math.ceil(vim.api.nvim_win_get_cursor(S.win.list)[1] / 2)]
end

local function open_note(file, focus)
  S.current = file
  vim.api.nvim_win_call(S.win.editor, function()
    vim.cmd("silent! update")
    vim.cmd("edit " .. vim.fn.fnameescape(file))
  end)
  render_list(false)
  if focus then vim.api.nvim_set_current_win(S.win.editor) end
end

-- close the buffer of a moved/deleted note (so autosave can't recreate it)
local function forget(file)
  local b = vim.fn.bufnr(file)
  if b == -1 then return end
  if alive(S.win.editor) and vim.api.nvim_win_get_buf(S.win.editor) == b then
    vim.api.nvim_win_set_buf(S.win.editor, vim.api.nvim_create_buf(false, true))
  end
  pcall(vim.api.nvim_buf_delete, b, { force = true })
end

function M.new_note()
  if not is_open() then return end
  if S.notebook == TRASH then S.notebook = M.config.default_notebook end
  S.query = nil
  refresh()
  -- the file is only written once you type something (no empty notes)
  open_note(nbpath(S.notebook) .. "/" .. os.date("%Y%m%d-%H%M%S") .. "." .. M.config.ext, true)
  vim.cmd("startinsert")
end

function M.trash()
  local n = current_note()
  if not n then return end
  forget(n.file)
  if n.nb == TRASH then
    if vim.fn.confirm("Delete permanently?", "&Yes\n&No", 2) ~= 1 then return refresh() end
    uv.fs_unlink(n.file)
  else
    vim.fn.mkdir(nbpath(TRASH), "p")
    uv.fs_rename(n.file, nbpath(TRASH) .. "/" .. vim.fs.basename(n.file))
  end
  if S.current == n.file then S.current = nil end
  refresh()
end

function M.restore()
  local n = current_note()
  if not n or n.nb ~= TRASH then return end
  forget(n.file)
  vim.fn.mkdir(nbpath(M.config.default_notebook), "p")
  uv.fs_rename(n.file, nbpath(M.config.default_notebook) .. "/" .. vim.fs.basename(n.file))
  if S.current == n.file then S.current = nil end
  refresh()
end

function M.search()
  vim.ui.input({ prompt = "Search: ", default = S.query or "" }, function(q)
    if q == nil then return end
    S.query = q ~= "" and q or nil
    refresh()
  end)
end

local function new_book()
  vim.ui.input({ prompt = "New notebook: " }, function(name)
    if not name then return end
    name = vim.trim(name)
    name = name:gsub("[/\\]", "-")
    name = name:gsub("^%.+", "")
    if name == "" then return end
    vim.fn.mkdir(nbpath(name), "p")
    S.notebook, S.query = name, nil
    refresh()
  end)
end

local function select_book()
  local nb = S.books[vim.api.nvim_win_get_cursor(S.win.books)[1]]
  if not nb then return end
  S.notebook, S.query = nb, nil
  refresh()
  vim.api.nvim_set_current_win(S.win.list)
  pcall(vim.api.nvim_win_set_cursor, S.win.list, { 1, 0 })
end

function M.close()
  if S.closing or not is_open() then return end
  S.closing = true
  if alive(S.win.editor) then
    vim.api.nvim_win_call(S.win.editor, function() vim.cmd("silent! update") end)
  end
  for _, k in ipairs({ "editor", "list", "books", "frame" }) do
    if alive(S.win[k]) then pcall(vim.api.nvim_win_close, S.win[k], true) end
    S.win[k] = nil
  end
  S.current = nil
  S.closing = false
  if S.app then
    S.app = false
    pcall(vim.cmd, "qall")
  end
end

-- app mode: for a dedicated terminal window  (nvim +NotesApp)
-- the notes fill the whole window and closing them quits nvim
function M.app()
  local function go() M.open({ app = true }) end
  if vim.v.vim_did_enter == 1 then
    go()
  else
    vim.api.nvim_create_autocmd("VimEnter", {
      once = true,
      callback = function() vim.defer_fn(go, 100) end,
    })
  end
end

function M.toggle()
  if is_open() then M.close() else M.open() end
end

-- ───────────────────────────── UI ──────────────────────────────────
local function map(buf, lhs, fn, desc)
  vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true, desc = "Notes: " .. desc })
end

local function goto_win(w) return function() if alive(w) then vim.api.nvim_set_current_win(w) end end end

local function setup_keymaps()
  local b, l = S.buf.books, S.buf.list

  map(b, "<CR>", select_book, "open notebook")
  map(b, "a", new_book, "new notebook")
  map(b, "n", M.new_note, "new note")
  map(b, "q", M.close, "close")
  map(b, "<Tab>", function() goto_win(S.win.list)() end, "go to list")

  map(l, "<CR>", function()
    local n = current_note()
    if n then open_note(n.file, true) end
  end, "open note")
  map(l, "n", M.new_note, "new note")
  map(l, "d", M.trash, "move to trash (or delete if in trash)")
  map(l, "r", M.restore, "restore from trash")
  map(l, "/", M.search, "search")
  map(l, "<Esc>", function()
    if S.query then S.query = nil; refresh() end
  end, "clear search")
  map(l, "q", M.close, "close")
  map(l, "<Tab>", function() goto_win(S.win.editor)() end, "go to editor")
  map(l, "<S-Tab>", function() goto_win(S.win.books)() end, "go to notebooks")
  -- j/k move note by note (each note takes 2 lines)
  map(l, "j", function() vim.cmd("normal! " .. 2 * vim.v.count1 .. "j") end, "next")
  map(l, "k", function() vim.cmd("normal! " .. 2 * vim.v.count1 .. "k") end, "previous")
end

-- geometry of the floating window (centered on screen)
local function layout()
  local cfg = M.config
  local function dim(v, total) return v <= 1 and math.floor(total * v) or v end
  local function clamp(v, lo, hi) return math.max(lo, math.min(v, hi)) end

  local w, h, row, col
  if S.app then
    -- app mode: fill the whole terminal window (the OS window is the "popup")
    local rows_used = vim.o.cmdheight + (vim.o.laststatus > 0 and 1 or 0)
    w, h, row, col = vim.o.columns - 2, vim.o.lines - rows_used - 2, 0, 0
  else
    local maxw, maxh = vim.o.columns - 4, vim.o.lines - 6
    w = clamp(dim(cfg.width, vim.o.columns), math.min(64, maxw), maxw)
    h = clamp(dim(cfg.height, vim.o.lines), math.min(12, maxh), maxh)
    row = math.max(math.floor((vim.o.lines - h - 2) / 2), 0)
    col = math.max(math.floor((vim.o.columns - w - 2) / 2), 0)
  end

  -- side panes shrink on small screens
  local bw = clamp(math.floor(w * 0.18), 12, cfg.books_width)
  local lw = clamp(math.floor(w * 0.32), 20, cfg.list_width)
  local ew = math.max(w - bw - lw, 10)

  local function rect(c, wd)
    return { relative = "editor", row = row + 1, col = col + 1 + c, width = wd, height = h }
  end
  return {
    frame = { relative = "editor", row = row, col = col, width = w, height = h },
    books = rect(0, bw),
    list = rect(bw, lw),
    editor = rect(bw + lw, ew),
  }
end

local function float(buf, cfg, extra)
  return vim.api.nvim_open_win(buf, false, vim.tbl_extend("force", cfg, { style = "minimal" }, extra or {}))
end

local function style_panel(win, bar)
  local wo = vim.wo[win]
  wo.cursorline, wo.wrap = true, false
  wo.winbar = bar
  wo.winhighlight = "Normal:NormalFloat,EndOfBuffer:NormalFloat"
end

function M.open(opts)
  if is_open() then
    vim.api.nvim_set_current_win(S.win.list)
    return
  end
  vim.fn.mkdir(nbpath(M.config.default_notebook), "p")
  S.notebook, S.query, S.current = M.config.default_notebook, nil, nil
  S.app = opts ~= nil and opts.app == true

  S.buf.frame, S.buf.books, S.buf.list, S.buf.editor = scratch(), scratch(), scratch(), scratch()
  local L = layout()
  S.win.frame = float(S.buf.frame, L.frame, {
    border = "rounded", title = " Notes ", title_pos = "center",
    focusable = false, zindex = 30,
  })
  vim.wo[S.win.frame].winhighlight =
    "Normal:NormalFloat,FloatBorder:" .. M.config.border_hl .. ",FloatTitle:" .. M.config.border_hl
  S.win.books = float(S.buf.books, L.books, { zindex = 31 })
  S.win.list = float(S.buf.list, L.list, { zindex = 31 })
  S.win.editor = float(S.buf.editor, L.editor, { zindex = 31 })

  style_panel(S.win.books, " Notebooks")
  style_panel(S.win.list, " n new  d delete  / search")
  local we = vim.wo[S.win.editor]
  we.wrap, we.linebreak, we.winbar, we.foldcolumn = true, true, " ", "1"

  -- closing any of the panes (e.g. :q in the editor) closes the whole thing
  local ui = vim.api.nvim_create_augroup("NotesUI", { clear = true })
  for _, k in ipairs({ "books", "list", "editor" }) do
    vim.api.nvim_create_autocmd("WinClosed", {
      group = ui, pattern = tostring(S.win[k]), once = true,
      callback = function() vim.schedule(M.close) end,
    })
  end

  setup_keymaps()
  refresh()
  if S.notes[1] then open_note(S.notes[1].file, false) end
  vim.api.nvim_set_current_win(S.win.list)
end

-- ───────────────────────────── setup ───────────────────────────────
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.config.dir = vim.fs.normalize(vim.fn.expand(M.config.dir))

  local function in_notes(buf)
    return vim.bo[buf].buftype == ""
      and vim.startswith(vim.api.nvim_buf_get_name(buf), M.config.dir .. "/")
  end

  local aug = vim.api.nvim_create_augroup("Notes", { clear = true })

  -- autosave
  vim.api.nvim_create_autocmd(
    { "TextChanged", "InsertLeave", "CursorHold", "CursorHoldI", "FocusLost" },
    {
      group = aug,
      callback = function(ev)
        if in_notes(ev.buf) and vim.bo[ev.buf].modified then
          vim.api.nvim_buf_call(ev.buf, function() vim.cmd("silent! write") end)
          if is_open() then refresh(true) end
        end
      end,
    }
  )

  -- refresh the list (title/date) after saving
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = aug,
    callback = function(ev)
      if in_notes(ev.buf) and is_open() then refresh(true) end
    end,
  })

  -- from the editor, <S-Tab> (normal mode) goes back to the note list
  vim.api.nvim_create_autocmd("BufEnter", {
    group = aug,
    callback = function(ev)
      if in_notes(ev.buf) then
        vim.keymap.set("n", "<S-Tab>", function()
          if alive(S.win.list) then vim.api.nvim_set_current_win(S.win.list) end
        end, { buffer = ev.buf, silent = true, desc = "Notes: go to list" })
      end
    end,
  })

  -- keep the window centered when the terminal is resized
  vim.api.nvim_create_autocmd("VimResized", {
    group = aug,
    callback = function()
      if not is_open() then return end
      for k, c in pairs(layout()) do
        if alive(S.win[k]) then vim.api.nvim_win_set_config(S.win[k], c) end
      end
    end,
  })

  vim.api.nvim_create_user_command("Notes", function() M.toggle() end, {})
  vim.api.nvim_create_user_command("NotesApp", function() M.app() end, {})
  vim.api.nvim_create_user_command("QuickNote", function()
    M.open()
    M.new_note()
  end, {})
end

return M
