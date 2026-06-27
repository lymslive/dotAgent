---
name: spop
description: "简单 task todo 工作流开发任务，无 log 阶段"
argument-hint: "[0 | yyyy-mm-dd/n]"
disable-model-invocation: true
---

## 需求获取 (/todo)

需求内容可用脚本从 `task_todo.md` 读取

```bash
perl ~/dotAgent/tool/todo.pl $1
```

脚本支持使用特定需求 ID 作为参数，或使用 0 自动查找第一个未完成的需求。
需求 ID 在二级标题处，格式是 `yyyy-mm-dd/n` 。

如果需求中有提及参考历史需求id ，也可用 `todo.pl <todo-id>` 读取；

## 实施阶段

- 先仔细分析用户需求内容，评估可行性与合理性，在需求有疑义时可再咨询用户确认。
- 如果任务较复杂，请先将实施计划写入 `doing_plan.tmp/` 子目录，确认后再开始。
- 如果评估为不合理需求，或者理解的需求不明确，可以再与用户沟通确认。

## 日志阶段

spop 不写单独的 `task_log.md` 日志文件，但仍需生成 `yyyymmdd-hhmmss` 格式
的任务ID，其将写回 `task_todo.md` 关联需求 ID ，用于标记完成

可用脚本命令更新： `perl ~/dotAgent/tool/todo.pl "需求ID" "任务ID"`

## 文档同步 (/tdoc)

如果当前任务对架构设计或用户接口有较大改动，请检查相关文档，作必要的同步更新：
- CLAUDE.md AGENTS.md
- README.MD readme.md
- docs/ 下有关用法或 api 说明的文档等

只检查更新，不新增文档，无相关文档则忽略


