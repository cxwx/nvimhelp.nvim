local M = {}

M.config = {
  -- 是否替换 F1 快捷键
  replace_f1 = true,
  -- 帮助语言优先级
  helplang = "zh",
  -- 没有中文翻译时是否回退到英文
  fallback_to_en = true,
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
  -- 尝试获取 <cWORD>，因为 help tag 可能包含特殊字符如 :, ', /
  local cword = vim.fn.expand("<cWORD>")
  -- 去掉 help tag 的包裹字符 |...|  *...*
  cword = cword:gsub("^[|*]+", ""):gsub("[|*]+$", "")
  if cword == "" then
    cword = vim.fn.expand("<cword>")
  end
  -- 去掉已有的 @zh 后缀，避免拼接成 tag@zh@zh
  cword = cword:gsub("@zh$", "")
  return cword
end

--- 获取可视模式选中的文本
--- @return string
local function get_visual_selection()
  local _, ls, cs = unpack(vim.fn.getpos("v"))
  local _, le, ce = unpack(vim.fn.getpos("."))
  -- 确保 start <= end
  if ls > le or (ls == le and cs > ce) then
    ls, cs, le, ce = le, ce, ls, cs
  end
  local lines = vim.api.nvim_buf_get_text(0, ls - 1, cs - 1, le - 1, ce, {})
  local text = table.concat(lines, "")
  -- 去掉包裹字符和 @zh 后缀
  text = text:gsub("^[|*]+", ""):gsub("[|*]+$", ""):gsub("@zh$", "")
  return text
end

--- 安全地执行 :help 命令（避免命令注入）
--- @param tag string
--- @return boolean ok
--- @return string|nil err
local function safe_help(tag)
  -- 使用 vim.cmd.help() 的函数形式，自动转义参数
  return pcall(vim.cmd.help, tag)
end

--- 尝试打开中文帮助，失败则回退英文
--- @param tag string 帮助标签
local function open_help_zh(tag)
  if tag == "" then
    tag = "help"
  end
  -- 先尝试中文版本
  local ok = safe_help(tag .. "@zh")
  if ok then
    return
  end
  -- 回退到英文
  if M.config.fallback_to_en then
    local ok2, err = safe_help(tag)
    if not ok2 then
      vim.notify("nvimhelp: 找不到帮助标签 '" .. tag .. "'", vim.log.levels.WARN)
    end
  else
    vim.notify("nvimhelp: 没有找到 '" .. tag .. "' 的中文帮助", vim.log.levels.WARN)
  end
end

--- F1 处理函数：取光标下的词打开中文帮助
function M.help_cursor()
  local word = get_cursor_word()
  open_help_zh(word)
end

--- 可视模式处理函数：取选中文本打开中文帮助
function M.help_visual()
  local text = get_visual_selection()
  -- 退出可视模式
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
  open_help_zh(text)
end

--- 交互式输入搜索帮助
function M.help_input()
  vim.ui.input({ prompt = "中文帮助: " }, function(input)
    if input and input ~= "" then
      open_help_zh(input)
    end
  end)
end

--- 使用 :HelpZh 命令直接查询
--- @param tag string
function M.help_cmd(tag)
  open_help_zh(tag)
end

--- 列出所有可用的中文帮助标签（用于补全，带缓存）
--- @return string[]
function M.complete_zh_tags(arglead, cmdline, cursorpos)
  local doc_path = plugin_root() .. "/doc/tags-zh"

  -- 检查文件修改时间，决定是否刷新缓存
  local stat = vim.uv.fs_stat(doc_path)
  if stat and stat.mtime and stat.mtime.sec ~= _tags_cache_mtime then
    _tags_cache = nil
  end

  -- 读取并缓存所有标签
  if not _tags_cache then
    _tags_cache = {}
    local f = io.open(doc_path, "r")
    if f then
      for line in f:lines() do
        local tag = line:match("^(%S+)")
        if tag then
          -- 去掉 @zh 后缀用于展示（用户输入时不需要加 @zh）
          table.insert(_tags_cache, (tag:gsub("@zh$", "")))
        end
      end
      f:close()
      if stat and stat.mtime then
        _tags_cache_mtime = stat.mtime.sec
      end
    end
  end

  -- 过滤匹配
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

  -- 将本插件的 doc 目录加入 runtimepath（确保 helptags 能被找到）
  local root = plugin_root()
  if not vim.o.runtimepath:find(root, 1, true) then
    vim.opt.runtimepath:append(root)
  end

  -- 设置 helplang（保留用户已有的设置，确保 zh 在最前面）
  local current = vim.o.helplang or ""
  if not current:find("zh", 1, true) then
    vim.o.helplang = M.config.helplang .. (current ~= "" and ("," .. current) or "") .. ",en"
  end

  -- 注册用户命令（先清理旧的，防止重复 setup）
  pcall(vim.api.nvim_del_user_command, "HelpZh")
  pcall(vim.api.nvim_del_user_command, "HelpZhInput")

  vim.api.nvim_create_user_command("HelpZh", function(cmd_opts)
    M.help_cmd(cmd_opts.args)
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
