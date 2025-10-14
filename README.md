

# ingest.sh


## The Problem

When working in restricted environments where AI coding assistants can't be installed, you're left with web-based AI chatbots. To get meaningful assistance, you need to provide context about your codebase, but manually copying and pasting files is tedious.

## Existing Solutions

There are some great tools out there that solve similar problems:
- [Gitingest](https://github.com/coderamp-labs/gitingest/) - A feature-rich Python package for ingesting Git repositories
- [Repomix](https://github.com/yamadashy/repomix) - A JavaScript/Node.js package for repository packing

## Why This

While these tools are excellent, they require installing packages which isn't straightforward in air-gapped work environments! So, I just wanted something more portable that doesn't require installing packages or dependencies. Just a simple shell script that works anywhere you have a terminal (bash or PowerShell).


## Quick Start

### Unix/Linux/macOS

```bash
# Download the script and save for later use
curl -sSL https://raw.githubusercontent.com/hamzakat/ingest.sh/main/ingest.sh -o ingest.sh
chmod +x ingest.sh
./ingest.sh /path/to/project

# Download and run directly on current directory
curl -sSL https://raw.githubusercontent.com/hamzakat/ingest.sh/main/ingest.sh | bash -s .
# You'll find the output in digest.txt

# Download and run on current directory and pipe the result
curl -sSL https://raw.githubusercontent.com/hamzakat/ingest.sh/main/ingest.sh | bash -s . -o - | ...

```

### Windows PowerShell

```powershell
# Download and run on current directory
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/hamzakat/ingest.sh/main/ingest.ps1" -OutFile "ingest.ps1"
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\ingest.ps1 -o -
```

## Usage Examples

### Basic Usage

```bash
# Analyze current directory
./ingest.sh

# Analyze specific directory
./ingest.sh /path/to/project

# Output to stdout
./ingest.sh -o -
```

### Integration with CLI Tools

```bash
# Pipe to Claude Code
./ingest.sh -o - | claude -p "Analyze this codebase"

# Pipe to llm tool (by https://github.com/simonw/llm)
./ingest.sh -o - | llm -s "Summarize this codebase"

```

## Options

| Option | Description |
|--------|-------------|
| `-o, --output FILE` | Output file path (default: digest.txt, use '-' for stdout) |
| `-i, --include PATTERN` | Include files matching pattern (can be used multiple times) |
| `-e, --exclude PATTERN` | Exclude files matching pattern (can be used multiple times) |
| `-s, --max-size SIZE` | Maximum file size (default: 1MB, can use K/M/G suffixes) |
| `-d, --debug` | Enable debug output |
| `-h, --help` | Show help message |

## Features

- **Zero dependencies**: Just a shell script that works out of the box
- **Cross-platform**: Available for both Unix/Linux (bash) and Windows (PowerShell)
- **Smart filtering**: Automatically excludes binary files, large files, and common non-source directories
- **Configurable options**: Include/exclude patterns, maximum file size, debug output
- **Jupyter notebook support**: Converts .ipynb files to readable markdown format (`jq` or `jupyter nbconvert` are required, otherwise you will get raw ouptputs)
- **Encoding handling**: Properly handles files with different character encodings
- **Output flexibility**: Can output to file or stdout for piping to other tools

## File Filtering

The script automatically excludes:

- Binary files (based on extension and content analysis)
- Large files (configurable size limit)
- Common non-source directories (.git, node_modules, __pycache__, etc.)
- Files with binary MIME types

It always includes common source code file types (.py, .js, .ts, .java, etc.) and configuration files.

## Contributing

This project is still in early development and needs more testing on diverse codebases. Since I built this in an afternoon, there's likely room for improvement! I welcome contributions in the following areas:

- Testing on different types of projects
- Improving file type detection
- Adding support for more file formats
- Enhancing the filtering logic
- Cross-platform compatibility improvements

Feel free to submit issues, feature requests, or pull requests!

## License

MIT License - see the [LICENSE](LICENSE) file for details.
