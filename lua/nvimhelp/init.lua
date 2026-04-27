local M = {}

M.config = {
  -- 是否替换 F1 快捷键
  replace_f1 = true,
  -- 帮助语言优先级
  helplang = "zh",
  -- 没有中文翻译时是否回退到英文
  fallback_to_en = true,
}

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
  return cword
end

--- 尝试打开中文帮助，失败则回退英文
--- @param tag string 帮助标签
local function open_help_zh(tag)
  -- 先尝试中文版本
  local ok = pcall(vim.cmd, "help " .. tag .. "@zh")
  if ok then
    return
  end
  -- 回退到英文
  if M.config.fallback_to_en then
    local ok2, err = pcall(vim.cmd, "help " .. tag)
    if not ok2 then
      vim.notify("nvimhelp: 找不到帮助标签 '" .. tag .. "'\n" .. tostring(err), vim.log.levels.WARN)
    end
  else
    vim.notify("nvimhelp: 没有找到 '" .. tag .. "' 的中文帮助", vim.log.levels.WARN)
  end
end

--- F1 处理函数：取光标下的词打开中文帮助
function M.help_cursor()
  local word = get_cursor_word()
  if word == "" then
    -- 没有光标下的词，打开主帮助页
    open_help_zh("help")
  else
    open_help_zh(word)
  end
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
  if tag == "" then
    open_help_zh("help")
  else
    open_help_zh(tag)
  end
end

--- 列出所有可用的中文帮助标签（用于补全）
--- @return string[]
function M.complete_zh_tags(arglead, cmdline, cursorpos)
  -- 查找本插件 doc 目录下的 tags 文件
  local tags = {}
  local doc_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h") .. "/doc/tags-zh"
  local f = io.open(doc_path, "r")
  if not f then
    return tags
  end
  for line in f:lines() do
    local tag = line:match("^(%S+)")
    if tag and tag:find(arglead, 1, true) == 1 then
      -- 去掉 @zh 后缀用于展示
      tag = tag:gsub("@zh$", "")
      table.insert(tags, tag)
    end
  end
  f:close()
  return tags
end

--- 设置插件
--- @param opts table|nil
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- 将本插件的 doc 目录加入 runtimepath（确保 helptags 能被找到）
  local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
  if not vim.o.runtimepath:find(plugin_root, 1, true) then
    vim.opt.runtimepath:append(plugin_root)
  end

  -- 设置 helplang
  vim.o.helplang = M.config.helplang .. ",en"

  -- 注册用户命令
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
      vim.cmd("stopinsert")
      M.help_cursor()
    end, { noremap = true, silent = true, desc = "中文帮助(光标下)" })
  end
end

return M
