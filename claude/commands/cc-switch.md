---
description: "切换 Claude Code 的 API 配置（封装 cc-switch.pl）"
argument-hint: "[--list | --List | --view <配置名> | --help | <配置名>]"
disable-model-invocation: true
allowed-tools: ["Bash", "Read"]
---

运行命令：`perl ~/.claude/cc-switch.pl $ARGUMENTS`

根据参数判断是否需要验证：

**只读操作**（`--list`、`--List`、`--view`、`--help`，或无参数）：
直接运行脚本并展示输出，无需后续验证。

**切换操作**（传入配置名，不含上述只读选项）：
1. 运行脚本执行切换，展示其输出。
2. 脚本成功后，读取 `~/.claude/settings.json` 的 `env` 节点，
   同时读取对应从配置文件 `~/.claude/cc-switch/<配置名>.json` 的 `env` 节点，
   对比两者是否一致，确认切换已生效。
3. 若一致，提示"切换验证通过"；若不一致，提示"切换验证失败，env 节点不匹配"并展示差异。
4. 切换 API 后端后，如果后续对话出现 API Error，可能是模型名与新端点不兼容，执行 `/model` 重新选择模型即可。
