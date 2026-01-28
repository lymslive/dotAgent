# dotAgent

A collection of dot configuration directories and tool scripts for AI agent development.

This repository contains:
- `tool/` - Custom Perl and shell scripts for automation and documentation tasks
- `claude/` - Claude AI agent configurations and custom commands
- `codebuddy/` - CodeBuddy AI agent configurations and custom commands
- `iflow/` - AI flow configurations and custom commands

## Usage

This repository is intended to be used as a git submodule in personal development projects.

To add as a submodule:
```bash
git submodule add https://github.com/lymslive/dotAgent.git dotAgent
```

To create soft links from dot directories to dotAgent subdirectories:
```bash
cd dotAgent && bash dot_link.sh
```

## Directories

### tool/
- `analyze_comments.pl` - Analyze code comments
- `csv2mdtable.pl` - Convert CSV to Markdown tables
- `extract_doc_examples.pl` - Extract documentation examples
- `gen_toc.pl` - Generate table of contents
- `mdtitle_order.pl` - Order Markdown titles
- `mdtitle_update.pl` - Update Markdown titles
- `stat_perf.pl` - Performance statistics
- `sync_doc_examples.pl` - Sync documentation examples
- `tlog.pl` - Task log management
- `todo.pl` - TODO management
- `tsv2mdtable.pl` - Convert TSV to Markdown tables
- `utable.pl` - Universal table utilities

### claude/, codebuddy/, iflow/
- Each contains `commands/` directory with custom agent commands
- Settings files for AI agent configurations

## dot_link.sh

The `dot_link.sh` script creates soft links from the parent project's dot directories (`.` prefixed) to the corresponding directories in `dotAgent`:
- `.tool` → `dotAgent/tool`
- `.claude` → `dotAgent/claude`
- `.codebuddy` → `dotAgent/codebuddy`
- `.iflow` → `dotAgent/iflow`

This allows the parent project to access these tools and configurations directly from their usual dot directory locations while keeping the actual files managed in this submodule.
