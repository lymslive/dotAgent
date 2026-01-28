#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

# 默认标题
my $default_head = "Test Cases List";
my $head = $default_head;
my $help = 0;

# 解析命令行参数
GetOptions(
    'head=s' => \$head,
    'help'   => \$help,
) or die "Usage: $0 [--head=title] [--help]\n";

# 显示帮助信息
if ($help) {
    print <<"END_HELP";
Usage: $0 [--head=title] [--help]

从测试程序的 --List 输出中提取用例信息并生成文档格式。

选项：
  --head=title    设置文档标题（默认："$default_head"）
  --help          显示此帮助信息

示例：
  ./path/to/utest --List | $0 --head="单元测试用例列表"
END_HELP
    exit 0;
}

# 从标准输入读取 --List 输出
my @lines = <STDIN>;
chomp @lines;

# 按文件名分组存储用例
my %files;
my $current_file;

foreach my $line (@lines) {
    next unless $line =~ /^(\w+)\t(\w+)\t([^\t]+)\t(\d+)\t(.+)$/;
    
    my ($case_name, $case_type, $file_name, $line_num, $description) = ($1, $2, $3, $4, $5);
    
    # 如果是 TOOL 类型，在名称后加 * 后缀
    if ($case_type eq 'TOOL') {
        $case_name .= '*';
    }
    
    push @{$files{$file_name}}, [$case_name, $description];
}

# 输出文档格式
print "# $head\n\n";

# 按文件名排序输出
foreach my $file_name (sort keys %files) {
    print "## $file_name\n\n";
    
    # 输出该文件的所有用例
    foreach my $case (@{$files{$file_name}}) {
        my ($case_name, $description) = @$case;
        print "- `$case_name` - $description\n";
    }
    
    print "\n";
}