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
