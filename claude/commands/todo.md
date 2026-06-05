---
description: "读取并完成一个快捷 TODO 需求"
disable-model-invocation: true
---

!`perl ~/dotAgent/tool/todo.pl $0`

---

如未能自动读取需求内容，可用脚本从 `task_todo.md` 读取：

```bash
perl ~/dotAgent/tool/todo.pl $0
```

脚本支持使用特定需求 ID 作为参数，或使用 `0` 自动查找第一个未完成的需求。
需求 ID 在二级标题处，格式是 `yyyy-mm-dd/n` 。
