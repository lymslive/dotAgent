# Agent 协作工作日志

格式：每个二级题为一条日志，由当前时间生成 task id `TASK:yyyymmdd-HHMMSS` 。

## TASK:yyyymmdd-HHMMSS
-----------------------

> TODO:引用的需求ID

## TASK:20260605-112431
-----------------------

> TODO:2026-06-05/1

### 任务概述

开发 `cc-switch.pl` 脚本，替代旧的软链接方式切换 Claude Code 的 API 配置。

### 完成内容

**新增文件**

- `~/.claude/cc-switch.pl`（同步到 `claude/cc-switch.pl`）：Perl 脚本，功能：
  - 按名称或完整路径选取 `~/.claude/cc-switch/` 下的从配置
  - 用从配置的 `env` 节点覆盖主配置 `~/.claude/settings.json` 的 `env`，其余配置保留
  - 写入前轮换备份：`settings.json~1`（最新）到 `~9`（最旧），超出 9 份自动丢弃
  - `--list` / `--List`（含 `--note` 注释）/ `--view`（查看 JSON）/ `--help` 选项
  - 内置 POD 文档，可 `perldoc cc-switch.pl` 查阅
  - UTF-8 支持：`use utf8` + `use open ':std', ':encoding(UTF-8)'`

**其他操作**

- `~/.claude/settings.json`：软链接转换为普通文件（以 `cc-settings.json` 内容为基础）
- `~/bin/cc-switch.pl`：建立软链接指向 `~/.claude/cc-switch.pl`，可全局调用

### 备注

- 测试切换两次导致出现 `~1` `~2` 两个备份文件，逻辑正常，用户已手动从 `~2` 恢复
- 当前 `settings.json` 使用 ppio claude-sonnet 配置，工作正常

### COMMIT: ecea05c4e4d5c48b53eb8719d005f39556cb93ed
### COMMIT: e54447e9bbfcc2ebc81dd3b0a6ae7a551141cc25

## TASK:20260613-222858
-----------------------

> TODO:2026-06-13/1

### 任务概述

重构 `tool/todo.pl` 和 `tool/tlog.pl` 两个脚本，增强功能。

### 完成内容

**重构 todo.pl**

- 新增 `-p|--path` 选项：支持指定目录及向上回溯查找 task_todo.md
- 新增 `ls|list|List` 子命令：列出需求 ID，不同级别显示
- 扩展数字参数：0 为第一个未完成需求，负数表示倒数，支持任意整数索引
- 智能 ID 识别：若传入任务 ID 格式，自动委托给 tlog.pl 执行
- 新增 `-h|--help` 和 `-v|--version` 选项
- 内置 POD 文档
- 保留原有的 `<todo-id> <task-id>` 更新模式

**重构 tlog.pl**

- 重新定义数字参数语义：
  - `n` (非负整数)：读取第 n 条日志，0-indexed
  - `-n`：读取最后 n 条日志
  - `+n`：读取开头 n 条日志（`+0` 仅打印文件头）
- 无参数默认读取最后 1 条日志
- 新增 `ls|list|List` 子命令：列出任务 ID，有 COMMIT 的标 [X]
- 新增 `-p|--path`、`-h|--help`、`-v|--version` 选项
- 智能 ID 识别：若传入需求 ID 格式，自动委托给 todo.pl 执行
- 内置 POD 文档

### 备注

- 两个脚本共享相同的选项解析、路径回溯、ID 识别和委托调用模式
- 委托调用通过在脚本所在目录查找另一个脚本实现
- 原 tlog.pl 的 `tlog.pl 1` 语义改变：原意为最后 1 条，现为第 2 条（0-indexed）
- 可通过 `tlog.pl -1` 达到原效果

### COMMIT: 7cc20d62b01eb611266c1d422e07da18782a4076

## TASK:20260701-092758
-----------------------

> TODO:2026-07-01/1

### 任务概述

优化 `cc-switch.pl` 脚本，支持快速切换回上次配置，并在列表显示中标记当前与上次配置。

### 完成内容

**settings.json 元信息**

- 新增 `cc-switch` 子节点，记录 `current` 与 `last` 两个配置名
- 每次切换自动更新 `current`，将旧 `current` 移至 `last`

**last 特殊配置名**

- `cc-switch.pl last` 切换回上次使用的配置，交换 `current` 与 `last` 记录
- 切换到 `last` 时**不备份** `settings.json~n`，避免无意义的备份膨胀

**--list / --List 增强**

- 当前配置用 `*` 前缀置顶标记，上次配置用 `#` 前缀（仿 vim `#` 表示 alternate buffer 的习惯）
- 其他配置前缀补两个空格，保持对齐
- 异常情况：若记录的 `current`/`last` 在 `~/.claude/cc-switch/` 中找不到对应文件，仍列出配置名并标记 `[Error] Not Found in ~/.claude/cc-switch`
- `--help` 中说明 `*` 和 `#` 标记含义

**同步**

- 更新后的脚本已同步复制到 `~/.claude/cc-switch.pl`

### COMMIT: 944f742c1764663a58e7d61f09dfe3661023fd6a

### COMMIT: 37a1addc1c61c6e520b98e636174dee8b145548b

## TASK:20261017-185600
-----------------------

> TODO:2026-10-17/1

### 任务概述

修复 `tool/todo.pl` 将 Markdown 水平线 `---` 误当作需求分段结束符的问题。

### 完成内容

- `parse_sections`：移除 `^---+\s*$` 的分段判定，仅按 `## TODO` 二级标题切分需求条目
- `find_section`：同步移除水平线作为章节结束的判定，读取与更新模式均不再被 `---` 截断
- 验证：含 `---` 的需求可完整读取，`ls|list|List` 与 `<todo-id> <task-id>` 更新模式均正常
