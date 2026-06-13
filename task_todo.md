# 原始需求管理

## TODO:2026-06-05/1 写 linux 版本的简单 cc-switch 脚本

此前，在 ~/.claude/cc-switch.sh 脚本中只用最原始的软链接方法切换 settings.json
配置。但后来发现 settings.json 中不仅有 env 配置 API 地址与密钥，还有各种使用
claude 的配置。用软链接的话，就要同步其他配置到各个文件，也不方便。

所以换个思路：
- 一个主配置 settings.json ，包含当前使用的所有配置
- 多个从配置，只含 evn 子结点，且约定放在 ~/.claude/cc-switch/ 子目录
- 切换配置时，只将某个从配置的 evn 结点覆盖主配置

修改文件：
- 将当前的 ~/.claude/settings.json 软链接换为普通文件，当作主配置
- 开发 ~/.clade/cc-switch.pl (或 .py) 脚本
- 在 ~/bin PATH 目录中建个软链接至 ~/.clade/cc-switch.pl ，能在随处使用
- 将 ~/.clade/cc-switch.pl 同步拷到本仓库 claude 目录下

cc-switch.pl 用法：
- 可接完整 json 路径名，如在 ~/.claude 目录下运行
  `./cc-switch.pl cc-switch/deepseek-ccs.jon` 可利用命令行补全文件名
- 只接从配置名，不包含目录与 `.json` 后缀，如在任意目录运行
  `cc-switch.pl deepseek-ccs` ，自动在 `~/.claude/cc-switch` 子目录查找
- 于是需要 `--list` 选项，列出当前可选的从配置名
- 扩展 `--List` 功能，也列出从配置 json 可能有的 `--note` 注释字段
- 支持 `--view` 打印从配置完整 json
- 支持 `--help` 打印用法说明
- 脚本也要有内置文档，可以比 `--help` 更详细

另注：cc-switch.pl 修改 ~/.claude/settings.json 之前要备份。
采用类似 cp 命令行的备份策略，改名加后缀 ~1 ~2 ，轮换最多备份 9 个历史配置。

### DONE: 20260605-112431

## TODO:2026-06-13/1 重构 tool/todo.pl tlog.pl 工具

这两个脚本的核心功能是读取任务管理文件，被 agent 的 skill 或命令调用：
- todo.pl: 读取 `task_todo.md` 的原始需求
- tlog.pl: 读取 `task_log.md` 的工作日志

### --path 指定目录
之前实现，是读取当前工作目录的 `task_todo.m` 或 `task_log.md` 文件。
现在再加一个选项 `-p|--path` 可以指定目录，以读取指定目录的任务文件。

并且开启上溯功能，如果指定目录没有任务文件，则试图在父目录寻找，一直上溯，
直到根目录，或没有读取权限为止。如果是在父目录或祖先目录找到的任务文件，
先往 stderr 打印一条提示实际读取任务文件的目录路径。

也允许不带参数的 `-p` 选项，表示只开启上溯功能，仍从当前目录开始查找任务文件。
没有 `-p` 选项时，同原来默认功能，只读当前目录的任务文件，不上溯。

### list 子命令

当第一个参数是 `ls|list|List` 时，只列出需求 id ，或任务 id 。
这三个子命令性质相同，但打印的信息依次增多。

- todo.pl ls: 只打印 `task_todo.md` 文件中的未完成需求 id ，
  不包含 `TODO:` 前缀，仅 `yyyy-mm-dd/n` 格式，每行一个；
- todo.pl list: 打印所有的需求 id，包含 `TODO:` 前缀。同时在前面再加 checkbox
  标记，已完成的是 `[X]`，未完成的是 `[O]` ；
- todo.pl List: 在 list 的基础上再打印标题，相当于原文件标题行，但是 `##` 替换
  为 `[X]` 或 `[O]`

类似地：
- tlog.pl ls: 只打印 `task_log.md` 文件中任务 id ，
  不包含 `TASK:` 前缀，仅 `yyyymmdd-HHMMSS` 格式，每行一个；
- tlog.pl list: 打印所有的任务 id，包含 `TASK:` 前缀。同时在前面再加 checkbox
  标记，有提交 COMMIT 的标 `[X]`，没有的标 `[O]` ；
- tlog.pl List: 在 list 的基础上每行后面再增加 COMMIT hash ，如果一个任务有多
  行 COMMIT ，只列第一个 hash 。

### 统一的数字参数意义

当前 `todo.pl` 只支持 `0` 与 `-1` 这两个特殊参数。扩展为支持任意整数参数。
相当于按 `todo.pl ls` 所列的顺序读取第几个未完成的需求。
而 `0` 表示第一个，`-1` 表示最后一个只是这种情况的自然特例。

对于 `tlog.pl` 的数字参数意义，重新定义，之前是 `1` 表示最后 1 条日志，与
`todo.pl` 的习惯不一样。因此也改为参考 `tlog.pl ls` 的序列：
- 纯数字 `n`：只读第几 `n` 条日志，索引为 `n` 的那条日志；
- 负数 `-n` ：读末尾的总计 `n` 日志；
- 负数 `+n` ：读开头的总计 `n` 日志；

因此 `tlog.pl +0` 实现与当前 `tlog.pl 0` 一样的效果，没有读日志，但会打印文件
头部（第一条日志之前可能的格式说明）。而现在的 `tlog.pl 0` 会读第一条日志。

### 智能识别需求 id 或任务 id 参数

- 需求 id 格式：`yyyy-mm-dd/n` ，可能有 `TODO:` 前缀
- 任务 id 格式：`yyyymmdd-HHMMSS` ，可能有 `TASK:` 前缀

如果用户给了相反的 id ，自动识别调用另一个脚本读取。
例如若尝试 `todo.pl yyyymmdd-HHMMSS` ，
则在 stderr 提示改用 `tlog.pl yyyymmdd-HHMMSS`，
并在脚本所在目录查找 `tlog.pl` 脚本，切换调用该脚本；
如果找不到另一个脚本，报错。

### help 文档

再总结一下，除了带 `-` 前缀的选项，参数支持如下模式：
- ls|list|List 这样的单词，表示子命令
- 纯数字，包含正负整数，表示读取参考 ls 列表的索引（或数量）对应的条目内容
- id ，按格式匹配自动换用 todo.pl 或 tlog.pl 读取指定 id 的条目
- 不满足以上模式的参数，报错

原则上只支持一个参数，但 `todo.pl <todo-id> <task-id>` 特例场景支持两个参数。

加上 `-h|--help` 选项支持，打印简明用法。也内置更详细的 pod 文档。

按习惯也加上 `-v|--version` 选项，打印版本号，目前是 `1.0` 。
### DONE: 20260613-222858
