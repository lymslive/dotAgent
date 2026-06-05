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
