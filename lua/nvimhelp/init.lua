local M = {}

M.config = {
  -- 是否替换 F1 快捷键
  replace_f1 = true,
}

-- 补全标签缓存
local _tags_cache = nil
local _tags_cache_mtime = 0

--- 获取插件根目录
--- @return string
local function plugin_root()
  return vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
end

--- 获取光标下的单词（适配 help tag 格式）
--- @return string
local function get_cursor_word()
  local cword = vim.fn.expand("<cWORD>")
  -- 去掉 help tag 的包裹字符 |...|  *...*
  cword = cword:gsub("^[|*]+", ""):gsub("[|*]+$", "")
  if cword == "" then
    cword = vim.fn.expand("<cword>")
  end
  return cword
end

--- 获取可视模式选中的文本
--- @return string
local function get_visual_selection()
  local _, ls, cs = unpack(vim.fn.getpos("v"))
  local _, le, ce = unpack(vim.fn.getpos("."))
  if ls > le or (ls == le and cs > ce) then
    ls, cs, le, ce = le, ce, ls, cs
  end
  local lines = vim.api.nvim_buf_get_text(0, ls - 1, cs - 1, le - 1, ce, {})
  local text = table.concat(lines, "")
  text = text:gsub("^[|*]+", ""):gsub("[|*]+$", "")
  return text
end

--- 打开帮助（直接使用原生 :help，因为我们的 tags 已在 runtimepath 前面）
--- @param tag string 帮助标签
local function open_help(tag)
  if tag == "" then
    tag = "help.txt"
  end
  local ok, err = pcall(vim.cmd.help, tag)
  if not ok then
    vim.notify("nvimhelp: 找不到帮助标签 '" .. tag .. "'", vim.log.levels.WARN)
  end
end

--- F1 处理函数：取光标下的词打开中文帮助
function M.help_cursor()
  open_help(get_cursor_word())
end

--- 可视模式处理函数
function M.help_visual()
  local text = get_visual_selection()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
  open_help(text)
end

--- 交互式输入搜索帮助
function M.help_input()
  vim.ui.input({ prompt = "中文帮助: " }, function(input)
    if input and input ~= "" then
      open_help(input)
    end
  end)
end

--- 列出所有可用的中文帮助标签（用于补全，带缓存）
--- @return string[]
function M.complete_zh_tags(arglead, cmdline, cursorpos)
  local doc_path = plugin_root() .. "/doc/tags"

  local stat = vim.uv.fs_stat(doc_path)
  if stat and stat.mtime and stat.mtime.sec ~= _tags_cache_mtime then
    _tags_cache = nil
  end

  if not _tags_cache then
    _tags_cache = {}
    local f = io.open(doc_path, "r")
    if f then
      for line in f:lines() do
        local tag = line:match("^(%S+)")
        if tag then
          table.insert(_tags_cache, tag)
        end
      end
      f:close()
      if stat and stat.mtime then
        _tags_cache_mtime = stat.mtime.sec
      end
    end
  end

  if not arglead or arglead == "" then
    return _tags_cache
  end
  local result = {}
  for _, tag in ipairs(_tags_cache) do
    if tag:find(arglead, 1, true) == 1 then
      table.insert(result, tag)
    end
  end
  return result
end

--- 设置插件
--- @param opts table|nil
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- 将本插件的根目录 **前置** 到 runtimepath，确保中文 tags 优先于英文原版
  local root = plugin_root()
  local rtp = vim.opt.runtimepath:get()
  -- 检查是否已在 rtp 中
  local found = false
  for _, p in ipairs(rtp) do
    if p == root then
      found = true
      break
    end
  end
  if not found then
    vim.opt.runtimepath:prepend(root)
  end

  -- 注册用户命令
  pcall(vim.api.nvim_del_user_command, "HelpZh")
  pcall(vim.api.nvim_del_user_command, "HelpZhInput")

  vim.api.nvim_create_user_command("HelpZh", function(cmd_opts)
    open_help(cmd_opts.args)
  end, {
    nargs = "?",
    complete = M.complete_zh_tags,
    desc = "打开中文帮助文档",
  })

  vim.api.nvim_create_user_command("HelpZhInput", function()
    M.help_input()
  end, {
    desc = "交互式搜索中文帮助",
  })

  -- 替换 F1 快捷键
  if M.config.replace_f1 then
    vim.keymap.set("n", "<F1>", M.help_cursor, { noremap = true, silent = true, desc = "中文帮助(光标下)" })
    vim.keymap.set("i", "<F1>", function()
      vim.cmd.stopinsert()
      M.help_cursor()
    end, { noremap = true, silent = true, desc = "中文帮助(光标下)" })
    vim.keymap.set("v", "<F1>", M.help_visual, { noremap = true, silent = true, desc = "中文帮助(选中文本)" })
  end
end

return M
