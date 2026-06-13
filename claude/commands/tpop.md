---
description: "按 task todo log 工作流完成一个开发任务"
disable-model-invocation: true
---

这是一个典型的开发任务的工作流，是几个阶段的顺序组合。几乎每个阶段也有相应的独
立的 slash 自定义命令（技能）对应，可以在意外中断时临时手动调用后续阶段。

## 需求获取 (/todo)

需求内容可用脚本从 `task_todo.md` 读取

```bash
perl ~/dotAgent/tool/todo.pl $1
```

脚本支持使用特定需求 ID 作为参数，或使用 0 自动查找第一个未完成的需求。
需求 ID 在二级标题处，格式是 `yyyy-mm-dd/n` 。

如果需求中有提及参考历史需求id ，也可用 `todo.pl <todo-id>` 读取；
如果提及参考历史任务 id ，可用 `tlog.pl <task-id>` 读取。

## 实施阶段

- 先仔细分析用户需求内容，评估可行性与合理性，在需求有疑义时可再咨询用户确认。
- 如果任务较复杂，请先将实施计划写入 `doing_plan.tmp/` 子目录，确认后再开始。
- 如果评估为不合理需求，或者理解的需求不明确，可以再与用户沟通确认。
- 如果自动 debug 陷入循环 5 次以上仍未能解决问题，可以放弃与终止任务，汇报当前进度。

## 日志阶段 (/tlog)

由当前时间生成任务 ID ，格式为 `yyyymmdd-hhmmss` ，可用 `date +"%Y%m%d-%H%M%S"` 命令。

以任务 ID 为二级标题在 `task_log.md` 末尾追加式作日志，参考已有格式。
- 可读取原日志文件前 100 行与后 100 行作为参考；
- 或用 `perl ~/dotAgent/tool/tlog.pl -n` 准确提取最后 `n` 条日志记录；
- 注意只能追加到原文件末尾，不要覆盖原文件或修改中间原有内容；
- 可以先覆盖式写入 `last_log.md` 临时文件；
  再用命令 `cat last_log.md >> task_log.md` 追加日志。
- 之后删除 `last_log.md` 或改名 `last_log.tmp` ，避免后续任务展示修改该文件的
  diff 内容，那是无意义的干扰。

再将任务 ID 写回 `task_todo.md` 关联需求 ID，
可用脚本命令更新： `perl ~/dotAgent/tool/todo.pl "需求ID" "任务ID"`

## 文档同步 (/tdoc)

如果当前任务对架构设计或用户接口有较大改动，请检查相关文档，作必要的同步更新：
- CLAUDE.md AGENTS.md
- README.MD readme.md
- docs/ 下有关用法或 api 说明的文档等

只检查更新，不新增文档，无相关文档则忽略

## 提交阶段 (/gc)

最后将当前修改提交 git ，提交消息格式按常见的 `type:` 规范前缀，
- 消息正文使用中文，描叙主要变更
- 例行修改的 task_todo.md 与 task_log.md 没必要体现在提交消息，但需要提交这两个文件
- 提交后可能有 hook 自动往 task_log.md 追加 COMMIT hast 信息，不要再二次循环提交

