#!/usr/bin/env perl
use strict;
use warnings;

# script/tlog.pl
# Usage:
#   perl script/tlog.pl [n]
# Extract last n log entries from task_log.md for AI reference
# Arguments:
#   n - number of log entries to extract (default: 1, can be 0)
# Output:
#   - File header (content before first ##)
#   - Last n log sections starting with ##

my $n = parse_argument(@ARGV);
my ($header, @sections) = parse_task_log($n);

print $header;
print @sections;

exit 0;

# Parse command line argument
sub parse_argument {
    my ($arg) = @_;
    my $default = 1;
    
    return $default unless defined $arg;
    
    if ($arg !~ /^\d+$/) {
        print STDERR "ERROR: Argument must be a non-negative integer\n";
        print STDERR "Usage: perl script/tlog.pl [n]\n";
        exit 1;
    }
    
    return int($arg);
}

# Parse task_log.md into header and sections, keeping only last n sections
sub parse_task_log {
    my ($max_sections) = @_;
    # Use ./task_log.md relative to CWD. This is intentional: the tool is designed
    # to be invoked from the relevant module/project directory, supporting both
    # single-repo projects (run from root) and monorepos with per-module log files.
    my $log_path = "./task_log.md";
    
    open my $fh, '<', $log_path or die "ERROR: cannot open $log_path: $!\n";
    my @lines = <$fh>;
    close $fh;
    
    my $header = '';
    my @sections;
    my $current_section = '';
    my $in_header = 1;
    
    for my $line (@lines) {
        if ($line =~ /^##\s/ && $in_header) {
            $in_header = 0;
            $current_section = $line;
        } elsif ($line =~ /^##\s/) {
            # Start of new section
            push @sections, $current_section if $current_section;
            
            # Keep only last max_sections sections to optimize memory
            if (@sections > $max_sections) {
                shift @sections;
            }
            
            $current_section = $line;
        } else {
            if ($in_header) {
                $header .= $line;
            } else {
                $current_section .= $line;
            }
        }
    }
    
    # Add the last section
    push @sections, $current_section if $current_section;
    
    # Final cleanup to ensure we only have max_sections
    if (@sections > $max_sections) {
        my $remove = @sections - $max_sections;
        splice @sections, 0, $remove;
    }
    
    return ($header, @sections);
}
