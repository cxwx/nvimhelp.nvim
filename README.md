# nvimhelp.nvim

Neovim 中文帮助文档插件。替换默认 `<F1>` 快捷键，提供中文版本的帮助文档。

## 功能

- 按 `<F1>` 自动查找光标下单词的中文帮助
- `:HelpZh {tag}` 命令直接查询中文帮助（支持 Tab 补全）
- `:HelpZhInput` 交互式搜索帮助
- 无中文翻译时自动回退到英文
- 利用 Neovim 原生 `helplang` 系统，兼容 `:help tag@zh` 语法

## 安装

### lazy.nvim

```lua
{
  "你的用户名/nvimhelp.nvim",
  config = function()
    require("nvimhelp").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "你的用户名/nvimhelp.nvim",
  config = function()
    require("nvimhelp").setup()
  end,
}
```

## 配置

```lua
require("nvimhelp").setup({
  replace_f1 = true,      -- 替换 F1 快捷键（默认 true）
  helplang = "zh",        -- 帮助语言优先级（默认 "zh"）
  fallback_to_en = true,  -- 没有中文翻译时回退到英文（默认 true）
})
```

## 使用

| 快捷键/命令 | 说明 |
|---|---|
| `<F1>` | 普通/插入模式下查找光标下单词的中文帮助 |
| `:HelpZh {tag}` | 查找指定标签的中文帮助 |
| `:HelpZh` | 打开帮助主页 |
| `:HelpZhInput` | 弹出输入框交互式搜索 |

## 已翻译文档

- `help.txt` - 帮助主页
- `intro.txt` - Vim 入门介绍（模式、按键记法）
- `motion.txt` - 光标移动命令（hjkl、单词、文本对象、搜索、标记）
- `insert.txt` - 插入和替换模式
- `change.txt` - 删除、修改、复制、粘贴、撤销
- `options.txt` - 常用选项说明

## 贡献翻译

1. 在 `doc/` 目录下创建 `{原文件名}.zhx` 文件（如 `scroll.zhx`）
2. 首行标签：`*scroll.txt@zh*`
3. 所有标签加 `@zh` 后缀：`*scrolling@zh*`
4. 运行 `:helptags doc/` 生成标签索引

## License

MIT
