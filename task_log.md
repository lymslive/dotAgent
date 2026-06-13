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

