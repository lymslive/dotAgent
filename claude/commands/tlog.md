---
description: "记录当前工作日志"
disable-model-invocation: true
---

请回顾当前工作，并结合 `git diff` 的实际修改，
追加式记录工作日志在 `task_log.md` 文件末尾。
可以用 `perl ~/dotAgent/tool/tlog.pl 2` 脚本打印最后两条日志的格式作为参考。
任务 ID 由当前时间生成，格式为 `yyyymmdd-hhmmss`。
没有本会话明确关联需求ID的，可写“即时需求”。

如果有需求ID(yyyy-mm-dd/n 格式)，再将任务 ID 写回 `task_todo.md` 关联需求 ID，
可用脚本命令更新： `perl ~/dotAgent/tool/todo.pl "需求ID" "任务ID"`
