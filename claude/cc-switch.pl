#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use JSON::PP;
use Getopt::Long qw(:config no_ignore_case bundling);
use open ':std', ':encoding(UTF-8)';

=pod

=head1 NAME

cc-switch.pl - 切换 Claude Code 的 API 配置

=head1 SYNOPSIS

  cc-switch.pl [选项] [配置名]

=head1 DESCRIPTION

管理 ~/.claude/settings.json 中的 env 配置节点，支持在多个 API 环境之间切换。

主配置文件为 ~/.claude/settings.json，包含所有 Claude Code 配置。
从配置文件存放在 ~/.claude/cc-switch/ 目录，每个文件只需包含 env 子节点。
切换时，先将主配置备份为 settings.json~1（轮换，最多保留 9 份历史），
再用从配置的 env 节点完全替换主配置的 env 节点，其余主配置内容保留不变。

切换记录保存在 ~/.claude/settings.json 的 cc-switch 子节点中：
  { "cc-switch": { "current": "claude-sonnet", "last": "deepseek-ccs" } }

特殊配置名 "last" 表示切换回上次使用的配置（不产生备份）。

从配置文件可含 "--note" 字段（JSON 注释约定），用于描述该配置的用途。

=head1 OPTIONS

=over 4

=item B<--list>

列出 ~/.claude/cc-switch/ 下所有可用的从配置名。% 标记当前配置，# 标记上次配置，二者置顶显示。

=item B<--List>

同 --list，但同时显示每个从配置的 --note 注释字段。

=item B<--view> 配置名

打印指定从配置的完整 JSON 内容，不执行切换。

=item B<--help>

打印简短用法说明。

=back

=head1 ARGUMENTS

=over 4

=item B<配置名>

可以是：

1. 特殊名 "last"：切换回上次使用的配置，交换 current 与 last 记录，不备份。

2. 从配置完整路径（如 ~/.claude/cc-switch/deepseek-ccs.json），
   方便在 ~/.claude 目录下利用 shell 补全：./cc-switch.pl cc-switch/deepseek-ccs.json

3. 仅配置名，不含目录和 .json 后缀（如 deepseek-ccs），
   脚本自动在 ~/.claude/cc-switch/ 目录查找对应文件。

=back

=head1 FILES

  ~/.claude/settings.json        主配置文件（切换目标）
  ~/.claude/settings.json~1      最近一次备份（最多保留 ~1 到 ~9，~9 最旧）
  ~/.claude/cc-switch/*.json     从配置文件（env 节点来源）

=head1 EXAMPLES

  # 列出可用配置（标记 current/last）
  cc-switch.pl --list

  # 列出配置及备注
  cc-switch.pl --List

  # 查看某配置内容
  cc-switch.pl --view deepseek-ccs

  # 切换到 deepseek-ccs 配置
  cc-switch.pl deepseek-ccs

  # 切换回上次使用的配置
  cc-switch.pl last

  # 使用文件名补全（在 ~/.claude 目录下）
  ./cc-switch.pl cc-switch/deepseek-ccs.json

=cut

# 配置路径
my $CLAUDE_DIR = "$ENV{HOME}/.claude";
my $SWITCH_DIR = "$CLAUDE_DIR/cc-switch";
my $SETTINGS   = "$CLAUDE_DIR/settings.json";

# 解析命令行选项
my ($opt_list, $opt_List, $opt_view, $opt_help);
GetOptions(
    'list'  => \$opt_list,
    'List'  => \$opt_List,
    'view'  => \$opt_view,
    'help'  => \$opt_help,
) or usage_exit(1);

if ($opt_help) {
    print_help();
    exit 0;
}

if ($opt_list || $opt_List) {
    list_configs($opt_List);
    exit 0;
}

my $config_arg = $ARGV[0];
unless (defined $config_arg) {
    print_help();
    exit 1;
}

my $config_path = resolve_config($config_arg);

if ($opt_view) {
    view_config($config_path);
    exit 0;
}

switch_config($config_path, $config_arg);
exit 0;

# -----------------------------------------------------------------------

sub resolve_config {
    my ($arg) = @_;

    # 特殊名 last：从元信息查找上次配置
    if ($arg eq 'last') {
        my $meta = load_metadata();
        my $last_name = $meta->{last};
        die "没有记录上次配置（未找到 cc-switch.last 元数据）\n"
            unless defined $last_name && $last_name ne '';
        my $path = "$SWITCH_DIR/$last_name.json";
        die "上次配置文件不存在: $path\n" unless -f $path;
        return $path;
    }

    # 如果是文件路径（含 .json 或含 /），直接用（支持相对路径和绝对路径）
    if ($arg =~ /\.json$/ || $arg =~ m{/}) {
        # 相对路径转为绝对路径
        unless ($arg =~ m{^/}) {
            $arg = "$ENV{PWD}/$arg";
        }
        die "配置文件不存在: $arg\n" unless -f $arg;
        return $arg;
    }

    # 否则在 cc-switch 目录中查找
    my $path = "$SWITCH_DIR/$arg.json";
    die "配置不存在: $path\n" unless -f $path;
    return $path;
}

sub list_configs {
    my ($show_note) = @_;

    # 读取元信息
    my $meta    = load_metadata();
    my $current = $meta->{current} // '';
    my $last    = $meta->{last}    // '';

    my @files = glob("$SWITCH_DIR/*.json");
    my %exists = map {
        my $n = $_;
        $n =~ s{.*/}{};
        $n =~ s/\.json$//;
        ($n => 1)
    } @files;

    # 构建输出行列表：[prefix, name, error_or_undef]
    my @rows;

    if ($current ne '') {
        my $err = $exists{$current} ? undef : '[Error] Not Found in ~/.claude/cc-switch';
        push @rows, ['%', $current, $err];
    }

    if ($last ne '' && $last ne $current) {
        my $err = $exists{$last} ? undef : '[Error] Not Found in ~/.claude/cc-switch';
        push @rows, ['#', $last, $err];
    }

    for my $file (sort @files) {
        my $name = $file;
        $name =~ s{.*/}{};
        $name =~ s/\.json$//;
        next if $name eq $current || $name eq $last;
        push @rows, ['  ', $name, undef];
    }

    if (!@rows && !@files) {
        print "没有找到从配置文件（目录: $SWITCH_DIR）\n";
        return;
    }

    for my $row (@rows) {
        my ($prefix, $name, $err) = @$row;

        # 标记符 % / # 对齐到 2 字符；普通行前缀为 "  "
        my $padded_prefix = ($prefix eq '  ') ? '  ' : sprintf("%-2s", $prefix);

        if (defined $err) {
            printf "%s%s  %s\n", $padded_prefix, $name, $err;
        } elsif ($show_note) {
            my $note = ($prefix ne '  ' || $exists{$name}) ? read_note("$SWITCH_DIR/$name.json") : undef;
            if (defined $note && $note ne '') {
                printf "%s%-24s  %s\n", $padded_prefix, $name, $note;
            } else {
                printf "%s%s\n", $padded_prefix, $name;
            }
        } else {
            printf "%s%s\n", $padded_prefix, $name;
        }
    }
}

sub load_metadata {
    return {} unless -f $SETTINGS;
    my $text = slurp($SETTINGS);
    my $data = eval { JSON::PP->new->relaxed->decode($text) };
    return {} unless defined $data && ref($data) eq 'HASH';
    my $meta = $data->{'cc-switch'};
    return (ref($meta) eq 'HASH') ? $meta : {};
}

sub read_note {
    my ($path) = @_;
    return undef unless -f $path;
    my $json_text = slurp($path);
    my $data = eval { JSON::PP->new->relaxed->decode($json_text) };
    return undef unless defined $data && ref($data) eq 'HASH';
    return $data->{'--note'};
}

sub view_config {
    my ($path) = @_;
    my $json_text = slurp($path);
    my $data = eval { JSON::PP->new->relaxed->decode($json_text) };
    if ($@) {
        die "JSON 解析失败: $@\n";
    }
    my $out = JSON::PP->new->utf8->pretty->canonical->encode($data);
    print $out;
}

sub switch_config {
    my ($sub_path, $orig_arg) = @_;
    my $is_last = (defined $orig_arg && $orig_arg eq 'last');

    # 读取主配置
    die "主配置文件不存在: $SETTINGS\n" unless -f $SETTINGS;
    my $main_text = slurp($SETTINGS);
    my $main_data = eval { JSON::PP->new->relaxed->decode($main_text) };
    die "主配置 JSON 解析失败: $@\n" if $@;

    # 读取从配置
    my $sub_text = slurp($sub_path);
    my $sub_data = eval { JSON::PP->new->relaxed->decode($sub_text) };
    die "从配置 JSON 解析失败: $@\n" if $@;

    unless (exists $sub_data->{env} && ref($sub_data->{env}) eq 'HASH') {
        die "从配置中没有找到有效的 env 节点: $sub_path\n";
    }

    # 提取配置名
    my $new_name = $sub_path;
    $new_name =~ s{.*/}{};
    $new_name =~ s/\.json$//;

    # 更新 cc-switch 元信息
    my $meta = ref($main_data->{'cc-switch'}) eq 'HASH' ? $main_data->{'cc-switch'} : {};
    if ($is_last) {
        # 切换到 last：交换 current 与 last，不备份
        ($meta->{current}, $meta->{last}) = ($meta->{last}, $meta->{current});
    } else {
        $meta->{last}    = $meta->{current} // '';
        $meta->{current} = $new_name;
    }
    $main_data->{'cc-switch'} = $meta;

    # 用从配置的 env 替换主配置的 env
    $main_data->{env} = $sub_data->{env};

    # 写回主配置前先备份（切换到 last 时不备份）
    backup_settings() unless $is_last;

    # 写回主配置（pretty 格式，保持可读性）
    my $new_text = JSON::PP->new->utf8->pretty->indent_length(2)->canonical(0)->encode($main_data);
    spew($SETTINGS, $new_text);

    print "已切换到: $new_name\n";
    if (exists $sub_data->{'--note'}) {
        print "备注: $sub_data->{'--note'}\n";
    }
}

sub backup_settings {
    my $max = 9;
    # 轮换：~max 直接丢弃，~(max-1)..~1 依次后移，当前文件存为 ~1
    if (-f "${SETTINGS}~${max}") {
        unlink "${SETTINGS}~${max}";
    }
    for my $i (reverse 1 .. $max - 1) {
        my $src = "${SETTINGS}~${i}";
        my $dst = "${SETTINGS}~" . ($i + 1);
        rename $src, $dst if -f $src;
    }
    if (-f $SETTINGS) {
        my $content = slurp($SETTINGS);
        spew("${SETTINGS}~1", $content);
    }
}

sub slurp {
    my ($path) = @_;
    open my $fh, '<:utf8', $path or die "无法读取文件 $path: $!\n";
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}

sub spew {
    my ($path, $content) = @_;
    open my $fh, '>:utf8', $path or die "无法写入文件 $path: $!\n";
    print $fh $content;
    close $fh;
}

sub print_help {
    print <<'END';
用法: cc-switch.pl [选项] [配置名]

选项:
  --list    列出可用的从配置名（% 当前配置，# 上次配置）
  --List    列出配置名及 --note 注释
  --view    打印指定从配置的 JSON 内容（不切换）
  --help    显示此帮助信息

配置名可以是:
  last                          切换回上次使用的配置（交换 current/last，不备份）
  deepseek-ccs                  从 ~/.claude/cc-switch/ 查找 deepseek-ccs.json
  cc-switch/deepseek-ccs.json   完整路径（相对或绝对），支持 shell 补全

示例:
  cc-switch.pl --list
  cc-switch.pl --List
  cc-switch.pl --view deepseek-ccs
  cc-switch.pl deepseek-ccs
  cc-switch.pl last
  ./cc-switch.pl cc-switch/deepseek-ccs.json

运行 `perldoc cc-switch.pl` 查看详细文档。
END
}

sub usage_exit {
    my ($code) = @_;
    print_help();
    exit $code;
}
