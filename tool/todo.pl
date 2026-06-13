#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use File::Basename;
use Cwd 'abs_path';

my $VERSION = '1.0';
my $SCRIPT  = 'todo.pl';
my $TARGET_FILE = 'task_todo.md';

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

# --- Dispatch ---
@positional >= 1 or die_usage();

my $arg1 = $positional[0];

if ($arg1 eq 'ls') {
    cmd_ls(\@lines);
} elsif ($arg1 eq 'list') {
    cmd_list(\@lines);
} elsif ($arg1 eq 'List') {
    cmd_List(\@lines);
} elsif (_is_integer_arg($arg1)) {
    cmd_read_by_index(\@lines, $arg1);
} elsif (_is_task_id($arg1)) {
    delegate_to('tlog.pl', @positional);
} elsif (_is_todo_id($arg1)) {
    my $todo_id = normalize_todo_id($arg1);
    if (@positional >= 2) {
        cmd_update(\@lines, $filepath, $todo_id, $positional[1]);
    } else {
        cmd_read(\@lines, $todo_id);
    }
} else {
    die "ERROR: Invalid argument: $arg1\nTry --help\n";
}

exit 0;

# ============================================================
# Help
# ============================================================

sub print_help {
    print <<"HELP";
$SCRIPT - Read/update task_todo.md

Usage:
  $SCRIPT [options] ls|list|List        List todo IDs
  $SCRIPT [options] <n>                 Read n-th undone todo (0=first, -1=last)
  $SCRIPT [options] <todo-id>           Read specific todo section
  $SCRIPT [options] <todo-id> <task-id> Mark todo as done with task-id

Options:
  -p, --path [dir]   Read from dir (or enable upward traversal if no dir)
  -h, --help          Show this help
  -v, --version       Show version

Subcommands:
  ls                 Print undone todo IDs (bare format), one per line
  list               Print all todo IDs with TODO: prefix and [O]/[X] checkbox
  List               Like list, but show full title line

Examples:
  $SCRIPT 0                    Read first undone todo
  $SCRIPT 2026-06-13/1         Read specific todo
  $SCRIPT 2026-06-13/1 20260613-120000   Mark as done
  $SCRIPT ls                   List undone todo IDs
  $SCRIPT -p ../other list     List from another directory
  $SCRIPT -p                   List with upward traversal from CWD
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

sub write_file {
    my ($path, @lines) = @_;
    open my $fh, '>', $path or die "ERROR: cannot write $path: $!\n";
    print $fh @lines;
    close $fh;
}

# ============================================================
# Section parsing
# ============================================================

sub parse_sections {
    my ($lines_ref) = @_;
    my @lines = @$lines_ref;
    my @sections;
    my $current;

    for my $i (0 .. $#lines) {
        if ($lines[$i] =~ /^##\s*TODO.?\s*(\d{4}-\d{2}-\d{2}\/\d+)/) {
            if ($current) {
                $current->{end} = $i;
                $current->{done} = _section_has_done(\@lines, $current->{beg}, $i);
                push @sections, $current;
            }
            $current = {
                id    => $1,
                title => $lines[$i],
                beg   => $i,
            };
        } elsif ($lines[$i] =~ /^---+\s*$/ && $current) {
            $current->{end} = $i;
            $current->{done} = _section_has_done(\@lines, $current->{beg}, $i);
            push @sections, $current;
            $current = undef;
        }
    }

    if ($current) {
        $current->{end} = scalar @lines;
        $current->{done} = _section_has_done(\@lines, $current->{beg}, $current->{end});
        push @sections, $current;
    }

    return @sections;
}

sub _section_has_done {
    my ($lines_ref, $beg, $end) = @_;
    for my $i ($beg .. $end - 1) {
        return 1 if $lines_ref->[$i] =~ /^###\s*DONE\s*:/;
    }
    return 0;
}

sub find_section {
    my ($lines_ref, $todo_id) = @_;
    my $esc = quotemeta($todo_id);
    my $re = qr/^##\s*TODO.?\s*$esc\b/;

    for my $i (0 .. $#$lines_ref) {
        if ($lines_ref->[$i] =~ $re) {
            my $end = scalar @$lines_ref;
            for my $j ($i + 1 .. $#$lines_ref) {
                if ($lines_ref->[$j] =~ /^##\s*TODO/ || $lines_ref->[$j] =~ /^---+\s*$/) {
                    $end = $j;
                    last;
                }
            }
            return ($i, $end);
        }
    }
    return (undef, undef);
}

# ============================================================
# Subcommands
# ============================================================

sub cmd_ls {
    my ($lines_ref) = @_;
    my @sections = parse_sections($lines_ref);
    for my $s (@sections) {
        next if $s->{done};
        print $s->{id}, "\n";
    }
}

sub cmd_list {
    my ($lines_ref) = @_;
    my @sections = parse_sections($lines_ref);
    for my $s (@sections) {
        my $mark = $s->{done} ? '[X]' : '[O]';
        print "$mark TODO:$s->{id}\n";
    }
}

sub cmd_List {
    my ($lines_ref) = @_;
    my @sections = parse_sections($lines_ref);
    for my $s (@sections) {
        my $mark = $s->{done} ? '[X]' : '[O]';
        my $title = $s->{title};
        chomp $title;
        $title =~ s/^##\s*/$mark /;
        print "$title\n";
    }
}

# ============================================================
# Read by numeric index (undone only, 0-indexed)
# ============================================================

sub cmd_read_by_index {
    my ($lines_ref, $arg) = @_;
    my @sections = parse_sections($lines_ref);
    my @undone = grep { !$_->{done} } @sections;

    die "ERROR: No undone TODO found\n" unless @undone;

    my $n = int($arg);
    my $idx;

    if ($arg !~ /^-/) {
        # Non-negative: 0 = first undone, 1 = second, ...
        $idx = $n;
    } else {
        # Negative: -1 = last undone, -2 = second-to-last, ...
        $idx = scalar(@undone) + $n;
    }

    if ($idx < 0 || $idx >= @undone) {
        die "ERROR: Index $arg out of range (0..$#undone for undone todos)\n";
    }

    _print_section($lines_ref, $undone[$idx]);
}

# ============================================================
# Read by todo-id
# ============================================================

sub cmd_read {
    my ($lines_ref, $todo_id) = @_;
    my ($beg, $end) = find_section($lines_ref, $todo_id);
    if (!defined $beg) {
        die "ERROR: TODO section not found for id: $todo_id\n";
    }
    _print_range($lines_ref, $beg, $end);
}

sub _print_section {
    my ($lines_ref, $s) = @_;
    _print_range($lines_ref, $s->{beg}, $s->{end});
}

sub _print_range {
    my ($lines_ref, $beg, $end) = @_;
    for my $i ($beg .. $end - 1) {
        print $lines_ref->[$i];
    }
}

# ============================================================
# Update mode: mark todo as done
# ============================================================

sub cmd_update {
    my ($lines_ref, $filepath, $todo_id, $task_id) = @_;

    $task_id =~ /\S/ or die "ERROR: <task-id> is empty\n";

    my @lines = @$lines_ref;
    my ($beg, $end) = find_section(\@lines, $todo_id);
    if (!defined $beg) {
        die "ERROR: TODO section not found for id: $todo_id\n";
    }

    my $done_re = qr/^###\s*DONE\s*:\s*(.*)\S\s*$/;
    my $done_line_idx;
    my @done_ids;
    for my $i ($beg .. $end - 1) {
        if ($lines[$i] =~ $done_re) {
            $done_line_idx = $i;
            my $tail = $1 // '';
            @done_ids = grep { length } split /\s+/, $tail;
            last;
        }
    }

    my @new_ids = @done_ids;
    my %seen = map { $_ => 1 } @done_ids;
    if (!$seen{$task_id}) {
        push @new_ids, $task_id;
    }

    my $newline = '### DONE:' . (@new_ids ? ' ' . join(' ', @new_ids) : '') . "\n";

    if (defined $done_line_idx) {
        $lines[$done_line_idx] = $newline;
        for (my $i = $done_line_idx + 1; $i < $end; $i++) {
            if ($lines[$i] =~ $done_re) {
                splice @lines, $i, 1;
                $end--;
                $i--;
            }
        }
    } else {
        splice @lines, $end, 0, ($newline);
        $end++;
        if ($end < @lines && $lines[$end] !~ /^\s*$/) {
            splice @lines, $end, 0, ("\n");
        }
    }

    write_file($filepath, @lines);
    print "OK: DONE updated for $todo_id with $task_id\n";
}

# ============================================================
# ID recognition helpers
# ============================================================

sub normalize_todo_id {
    my ($s) = @_;
    $s =~ s/^TODO:?\s*//i;
    return $s;
}

sub _is_todo_id {
    my ($s) = @_;
    return 0 unless defined $s;
    my $clean = $s;
    $clean =~ s/^TODO:?\s*//i;
    return $clean =~ /^\d{4}-\d{2}-\d{2}\/\d+$/;
}

sub _is_task_id {
    my ($s) = @_;
    return 0 unless defined $s;
    my $clean = $s;
    $clean =~ s/^TASK:?\s*//i;
    return $clean =~ /^\d{8}-\d{6}$/;
}

sub _is_integer_arg {
    my ($s) = @_;
    return 0 unless defined $s;
    return $s =~ /^[+-]?\d+$/;
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
  todo.pl [options] ls|list|List
  todo.pl [options] <n>
  todo.pl [options] <todo-id>
  todo.pl [options] <todo-id> <task-id>
Try --help for details.
USAGE
    exit 1;
}

__END__

=head1 NAME

todo.pl - Read and update task_todo.md requirement files

=head1 SYNOPSIS

  perl todo.pl [options] ls|list|List
  perl todo.pl [options] <n>
  perl todo.pl [options] <todo-id>
  perl todo.pl [options] <todo-id> <task-id>

=head1 DESCRIPTION

This script reads and updates C<task_todo.md> files used for task management.
It can list todo IDs, read specific sections by index or ID, and mark todos
as done by recording associated task IDs.

=head1 OPTIONS

=over 4

=item -p, --path [dir]

Specify a directory to read C<task_todo.md> from. If a directory is given,
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

=item ls

Print only undone todo IDs (bare format C<yyyy-mm-dd/n>), one per line.

=item list

Print all todo IDs with C<TODO:> prefix and C<[O]> (undone) / C<[X]> (done) checkbox.

=item List

Like C<list>, but show the full title line (C<##> replaced by checkbox).

=item <n>

Read the n-th undone todo section, 0-indexed. C<0> is the first undone,
C<-1> is the last undone.

=item <todo-id>

Read the specific todo section by ID (C<yyyy-mm-dd/n> format, optionally
with C<TODO:> prefix).

=item <todo-id> <task-id>

Mark the todo as done by appending/merging C<### DONE: task-id>.

If a task ID (C<yyyymmdd-HHMMSS> format) is given to C<todo.pl>, it will
automatically delegate to C<tlog.pl> in the same directory.

=back

=head1 EXAMPLES

  # Read first undone todo
  perl todo.pl 0

  # Read specific todo
  perl todo.pl 2026-06-13/1

  # Mark todo as done
  perl todo.pl 2026-06-13/1 20260613-120000

  # List all undone IDs
  perl todo.pl ls

  # List all with checkbox
  perl todo.pl list

  # List all with titles
  perl todo.pl List

  # Read from a specific directory
  perl todo.pl -p /path/to/project 0

  # Enable upward traversal from CWD
  perl todo.pl -p ls

=head1 SEE ALSO

tlog.pl - Read task_log.md work log files

=cut
