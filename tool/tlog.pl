#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use File::Basename;
use Cwd 'abs_path';

my $VERSION = '1.0';
my $SCRIPT  = 'tlog.pl';
my $TARGET_FILE = 'task_log.md';

# --- Parse options ---
my ($opt_path, $opt_help, $opt_version);
my @positional;

while (@ARGV) {
    my $arg = shift @ARGV;
    if ($arg eq '-h' || $arg eq '--help') {
        $opt_help = 1;
    } elsif ($arg eq '-v' || $arg eq '--version') {
        $opt_version = 1;
    } elsif ($arg eq '-p' || $arg eq '--path') {
        if (_looks_like_positional($ARGV[0])) {
            $opt_path = '';
        } else {
            $opt_path = shift @ARGV // '';
        }
    } elsif ($arg =~ /^-\d+$/) {
        # Negative number: treat as positional, not option
        push @positional, $arg;
    } elsif ($arg =~ /^-./) {
        die "ERROR: Unknown option: $arg\nTry --help\n";
    } else {
        push @positional, $arg;
    }
}

# --- Handle help/version ---
if ($opt_help)    { print_help();    exit 0; }
if ($opt_version) { print "$VERSION\n"; exit 0; }

# --- Resolve file path ---
my $filepath = resolve_path($opt_path, $TARGET_FILE);

# --- Read file ---
my @lines = read_file($filepath);

# --- Parse sections ---
my ($header, @sections) = parse_sections(\@lines);

# --- Dispatch ---
if (@positional == 0) {
    # Default: read last 1 entry
    cmd_read_last_n(\@lines, $header, \@sections, 1);
    exit 0;
}

my $arg1 = $positional[0];

if ($arg1 eq 'ls') {
    cmd_ls(\@sections);
} elsif ($arg1 eq 'list') {
    cmd_list(\@sections);
} elsif ($arg1 eq 'List') {
    cmd_List(\@sections);
} elsif ($arg1 =~ /^\+(\d+)$/) {
    # +n: read first n tasks (+0 = header only)
    cmd_read_first_n(\@lines, $header, \@sections, int($1));
} elsif ($arg1 =~ /^-(\d+)$/) {
    # -n: read last n tasks
    cmd_read_last_n(\@lines, $header, \@sections, int($1));
} elsif ($arg1 =~ /^\d+$/) {
    # Non-negative integer: read n-th task (0-indexed)
    cmd_read_nth(\@lines, $header, \@sections, int($arg1));
} elsif (_is_todo_id($arg1)) {
    # Delegate to todo.pl
    delegate_to('todo.pl', @positional);
} elsif (_is_task_id($arg1)) {
    my $task_id = normalize_task_id($arg1);
    cmd_read_task(\@lines, $header, \@sections, $task_id);
} else {
    die "ERROR: Invalid argument: $arg1\nTry --help\n";
}

exit 0;

# ============================================================
# Help
# ============================================================

sub print_help {
    print <<"HELP";
$SCRIPT - Read task_log.md work log files

Usage:
  $SCRIPT [options]                    Read last log entry (default)
  $SCRIPT [options] ls|list|List       List task IDs
  $SCRIPT [options] <n>                Read n-th task (0-indexed)
  $SCRIPT [options] -<n>               Read last n tasks
  $SCRIPT [options] +<n>               Read first n tasks (+0 = header only)
  $SCRIPT [options] <task-id>          Read specific task section

Options:
  -p, --path [dir]   Read from dir (or enable upward traversal if no dir)
  -h, --help          Show this help
  -v, --version       Show version

Subcommands:
  ls                 Print task IDs (bare format), one per line
  list               Print all task IDs with TASK: prefix and [O]/[X] checkbox
  List               Like list, but append first COMMIT hash

Examples:
  $SCRIPT                         Read last log entry
  $SCRIPT 0                       Read first log entry
  $SCRIPT -3                      Read last 3 log entries
  $SCRIPT +0                      Print header only (no sections)
  $SCRIPT 20260605-112431         Read specific task
  $SCRIPT ls                      List all task IDs
  $SCRIPT -p ../other list        List from another directory
  $SCRIPT -p                      List with upward traversal from CWD
HELP
}

# ============================================================
# Path resolution
# ============================================================

sub resolve_path {
    my ($opt_path, $filename) = @_;

    if (!defined $opt_path) {
        my $path = "./$filename";
        die "ERROR: $filename not found in current directory\n" unless -f $path;
        return $path;
    }

    my $dir = ($opt_path eq '') ? '.' : $opt_path;
    $dir = abs_path($dir);
    my $start_dir = $dir;

    while (1) {
        my $path = "$dir/$filename";
        if (-f $path && -r $path) {
            if ($dir ne $start_dir) {
                print STDERR "Note: found $filename in $dir/\n";
            }
            return $path;
        }
        my $parent = dirname($dir);
        last if $parent eq $dir;
        $dir = $parent;
    }

    die "ERROR: $filename not found in $start_dir or any parent directory\n";
}

# ============================================================
# File I/O
# ============================================================

sub read_file {
    my ($path) = @_;
    open my $fh, '<', $path or die "ERROR: cannot open $path: $!\n";
    my @lines = <$fh>;
    close $fh;
    return @lines;
}

# ============================================================
# Section parsing for task_log.md
# ============================================================

sub parse_sections {
    my ($lines_ref) = @_;
    my @lines = @$lines_ref;
    my $header = '';
    my @sections;
    my $current;

    my $in_header = 1;

    for my $i (0 .. $#lines) {
        if ($lines[$i] =~ /^##\s*TASK:?\s*(\d{8}-\d{6})/) {
            if ($in_header) {
                $in_header = 0;
            } else {
                if ($current) {
                    $current->{end} = $i;
                    $current->{commits} = _extract_commits(\@lines, $current->{beg}, $i);
                    push @sections, $current;
                }
            }
            $current = {
                id  => $1,
                beg => $i,
            };
        } elsif ($in_header) {
            $header .= $lines[$i];
        }
    }

    if ($current) {
        $current->{end} = scalar @lines;
        $current->{commits} = _extract_commits(\@lines, $current->{beg}, $current->{end});
        push @sections, $current;
    }

    return ($header, @sections);
}

sub _extract_commits {
    my ($lines_ref, $beg, $end) = @_;
    my @commits;
    for my $i ($beg .. $end - 1) {
        if ($lines_ref->[$i] =~ /^###\s*COMMIT:\s*([a-f0-9]+)/) {
            push @commits, $1;
        }
    }
    return \@commits;
}

sub find_task_section {
    my ($sections_ref, $task_id) = @_;
    for my $s (@$sections_ref) {
        return $s if $s->{id} eq $task_id;
    }
    return undef;
}

# ============================================================
# Subcommands
# ============================================================

sub cmd_ls {
    my ($sections_ref) = @_;
    for my $s (@$sections_ref) {
        print $s->{id}, "\n";
    }
}

sub cmd_list {
    my ($sections_ref) = @_;
    for my $s (@$sections_ref) {
        my $mark = @{$s->{commits}} ? '[X]' : '[O]';
        print "$mark TASK:$s->{id}\n";
    }
}

sub cmd_List {
    my ($sections_ref) = @_;
    for my $s (@$sections_ref) {
        my $mark = @{$s->{commits}} ? '[X]' : '[O]';
        my $commit = @{$s->{commits}} ? " " . $s->{commits}[0] : '';
        print "$mark TASK:$s->{id}$commit\n";
    }
}

# ============================================================
# Read modes
# ============================================================

sub cmd_read_nth {
    my ($lines_ref, $header, $sections_ref, $n) = @_;

    die "ERROR: No task entries found\n" unless @$sections_ref;

    if ($n < 0 || $n >= @$sections_ref) {
        die "ERROR: Index $n out of range (0..$#$sections_ref)\n";
    }

    my $s = $sections_ref->[$n];
    print $header;
    _print_range($lines_ref, $s->{beg}, $s->{end});
}

sub cmd_read_last_n {
    my ($lines_ref, $header, $sections_ref, $n) = @_;

    die "ERROR: No task entries found\n" unless @$sections_ref;

    $n = scalar @$sections_ref if $n > @$sections_ref;

    print $header;
    my @selected = @$sections_ref[-$n .. -1] if $n > 0;
    for my $s (@selected) {
        _print_range($lines_ref, $s->{beg}, $s->{end});
    }
}

sub cmd_read_first_n {
    my ($lines_ref, $header, $sections_ref, $n) = @_;

    print $header;
    return if $n == 0;

    $n = scalar @$sections_ref if $n > @$sections_ref;

    my @selected = @$sections_ref[0 .. $n - 1];
    for my $s (@selected) {
        _print_range($lines_ref, $s->{beg}, $s->{end});
    }
}

sub cmd_read_task {
    my ($lines_ref, $header, $sections_ref, $task_id) = @_;
    my $s = find_task_section($sections_ref, $task_id);
    if (!$s) {
        die "ERROR: Task section not found for id: $task_id\n";
    }
    print $header;
    _print_range($lines_ref, $s->{beg}, $s->{end});
}

sub _print_range {
    my ($lines_ref, $beg, $end) = @_;
    for my $i ($beg .. $end - 1) {
        print $lines_ref->[$i];
    }
}

# ============================================================
# ID recognition helpers
# ============================================================

sub normalize_task_id {
    my ($s) = @_;
    $s =~ s/^TASK:?\s*//i;
    return $s;
}

sub _is_task_id {
    my ($s) = @_;
    return 0 unless defined $s;
    my $clean = $s;
    $clean =~ s/^TASK:?\s*//i;
    return $clean =~ /^\d{8}-\d{6}$/;
}

sub _is_todo_id {
    my ($s) = @_;
    return 0 unless defined $s;
    my $clean = $s;
    $clean =~ s/^TODO:?\s*//i;
    return $clean =~ /^\d{4}-\d{2}-\d{2}\/\d+$/;
}

sub _looks_like_positional {
    my ($s) = @_;
    return 0 unless defined $s;
    return 1 if $s eq 'ls' || $s eq 'list' || $s eq 'List';
    return 1 if $s =~ /^[+-]?\d+$/;
    return 1 if $s =~ /^(?:TODO:?\s*)?\d{4}-\d{2}-\d{2}\/\d+$/;
    return 1 if $s =~ /^(?:TASK:?\s*)?\d{8}-\d{6}$/;
    return 0;
}

# ============================================================
# Cross-script delegation
# ============================================================

sub delegate_to {
    my ($target_script, @args) = @_;

    my $script_dir = dirname(abs_path($0));
    my $target = "$script_dir/$target_script";

    print STDERR "Hint: use '$target_script' for this ID type, delegating...\n";

    if (-f $target) {
        exec 'perl', $target, @args;
        die "ERROR: failed to exec $target: $!\n";
    } else {
        die "ERROR: $target_script not found in $script_dir/\n";
    }
}

# ============================================================
# Usage
# ============================================================

sub die_usage {
    print STDERR <<'USAGE';
Usage:
  tlog.pl [options]
  tlog.pl [options] ls|list|List
  tlog.pl [options] <n>
  tlog.pl [options] -<n>
  tlog.pl [options] +<n>
  tlog.pl [options] <task-id>
Try --help for details.
USAGE
    exit 1;
}

__END__

=head1 NAME

tlog.pl - Read task_log.md work log files

=head1 SYNOPSIS

  perl tlog.pl [options]
  perl tlog.pl [options] ls|list|List
  perl tlog.pl [options] <n>
  perl tlog.pl [options] -<n>
  perl tlog.pl [options] +<n>
  perl tlog.pl [options] <task-id>

=head1 DESCRIPTION

This script reads C<task_log.md> files used for work log management.
It can list task IDs, read specific sections by index or ID, and
supports various numeric modes for convenient access.

=head1 OPTIONS

=over 4

=item -p, --path [dir]

Specify a directory to read C<task_log.md> from. If a directory is given,
start searching from that directory. If no directory is given (C<-p> alone),
enable upward traversal from the current working directory.

When upward traversal is enabled, the script searches parent directories
until the file is found. If found in an ancestor directory, a note is
printed to stderr.

Without C<-p>, the script only looks in the current working directory.

=item -h, --help

Print help message and exit.

=item -v, --version

Print version and exit.

=back

=head1 ARGUMENTS

=over 4

=item (no argument)

Read the last 1 log entry (same as C<-1>).

=item ls

Print all task IDs (bare format C<yyyymmdd-HHMMSS>), one per line.

=item list

Print all task IDs with C<TASK:> prefix and C<[O]> (no commit) / C<[X]> (has commit) checkbox.

=item List

Like C<list>, but append the first COMMIT hash for each task.

=item <n>

Read the n-th task section, 0-indexed. C<0> is the first task.

=item -<n>

Read the last n task sections.

=item +<n>

Read the first n task sections. C<+0> prints only the file header.

=item <task-id>

Read the specific task section by ID (C<yyyymmdd-HHMMSS> format, optionally
with C<TASK:> prefix).

If a todo ID (C<yyyy-mm-dd/n> format) is given to C<tlog.pl>, it will
automatically delegate to C<todo.pl> in the same directory.

=back

=head1 EXAMPLES

  # Read last log entry
  perl tlog.pl

  # Read first log entry
  perl tlog.pl 0

  # Read last 3 log entries
  perl tlog.pl -3

  # Print header only
  perl tlog.pl +0

  # Read specific task
  perl tlog.pl 20260605-112431

  # List all task IDs
  perl tlog.pl ls

  # List with checkbox
  perl tlog.pl list

  # List with COMMIT hash
  perl tlog.pl List

  # Read from a specific directory
  perl tlog.pl -p /path/to/project -3

  # Enable upward traversal from CWD
  perl tlog.pl -p ls

=head1 SEE ALSO

todo.pl - Read and update task_todo.md requirement files

=cut
