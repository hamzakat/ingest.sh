# Default ignore patterns for files and directories
 $DEFAULT_IGNORE_PATTERNS = @(
    ".git"
    ".gitignore"
    "__pycache__"
    "node_modules"
    ".venv"
    ".vscode"
    ".idea"
    "*.log"
    "*.tmp"
    "digest.txt"
    ".DS_Store"
    "Thumbs.db"
    "*.egg-info"
    "dist"
    "build"
    ".pytest_cache"
    ".coverage"
    "htmlcov"
    "*.pyc"
    "*.pyo"
    # Common non-source file patterns
    "runs/*"
    "videos/*"
    "wandb/*"
    "img/*"
    "logs/*"
    # Binary file extensions
    "*.mp4"
    "*.avi"
    "*.mov"
    "*.mkv"
    "*.jpg"
    "*.jpeg"
    "*.png"
    "*.gif"
    "*.bmp"
    "*.svg"
    "*.ico"
    "*.pdf"
    "*.zip"
    "*.tar"
    "*.gz"
    "*.rar"
    "*.exe"
    "*.dll"
    "*.so"
    "*.dylib"
    "*.bin"
    "*.dat"
    "*.pt"
    "*.pth"
    "*.pkl"
    "*.pickle"
    "*.wandb"
    "*.tfevents.*"
    "*.model"
    "*.ckpt"
    "*.checkpoint"
    "*.safetensors"
)

# Configuration
 $MAX_FILE_SIZE = 1MB  # Default max file size
 $TEXT_FILE_EXTENSIONS = @(
    "py", "js", "ts", "java", "cpp", "c", "h", "hpp", "cs", "php", "rb", "go", "rs", 
    "swift", "kt", "scala", "sh", "bash", "zsh", "fish", "ps1", "bat", "cmd", "html", 
    "htm", "css", "scss", "sass", "less", "xml", "json", "yaml", "yml", "toml", "ini", 
    "cfg", "conf", "md", "txt", "rst", "tex", "sql", "r", "m", "pl", "lua", "vim", 
    "dockerfile", "makefile", "cmake", "requirements.txt", "setup.py", "package.json", 
    "tsconfig.json", "webpack.config.js", "babel.config.js", ".eslintrc.js", ".prettierrc", 
    "gitignore", "gitattributes", "editorconfig", "license", "readme", "changelog", 
    "contributing", "install", "news", "authors", "history", "todo", "faq", "security", 
    "conduct", "changes", "version", "manifest", "metadata", "diff", "patch", "ipynb"
)

# Show help information
function Show-Help {
    Write-Host "Usage: .\ingest.ps1 [options] [source directory]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -o, --output FILE     Output file path (default: digest.txt, use '-' for stdout)"
    Write-Host "  -i, --include PATTERN Include files matching pattern (can be used multiple times)"
    Write-Host "  -e, --exclude PATTERN Exclude files matching pattern (can be used multiple times)"
    Write-Host "  -s, --max-size SIZE   Maximum file size (default: 1MB)"
    Write-Host "  -d, --debug           Enable debug output"
    Write-Host "  -h, --help            Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\ingest.ps1 C:\path\to\project"
    Write-Host "  .\ingest.ps1 -o summary.txt -i '*.py' -i '*.js' C:\path\to\project"
    Write-Host "  .\ingest.ps1 --output - C:\path\to\project  # Output to stdout"
    Write-Host "  .\ingest.ps1 -s 2MB C:\path\to\project  # Set max file size to 2MB"
}

# Parse command line arguments
 $OUTPUT_FILE = "digest.txt"
 $SOURCE_DIR = "."
 $INCLUDE_PATTERNS = @()
 $EXCLUDE_PATTERNS = @()
 $DEBUG = $false

for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        { $_ -eq "-o" -or $_ -eq "--output" } {
            if ($i + 1 -lt $args.Count) {
                $OUTPUT_FILE = $args[$i + 1]
                $i++
            } else {
                Write-Error "Missing value for $($args[$i])"
                exit 1
            }
        }
        { $_ -eq "-i" -or $_ -eq "--include" } {
            if ($i + 1 -lt $args.Count) {
                $INCLUDE_PATTERNS += $args[$i + 1]
                $i++
            } else {
                Write-Error "Missing value for $($args[$i])"
                exit 1
            }
        }
        { $_ -eq "-e" -or $_ -eq "--exclude" } {
            if ($i + 1 -lt $args.Count) {
                $EXCLUDE_PATTERNS += $args[$i + 1]
                $i++
            } else {
                Write-Error "Missing value for $($args[$i])"
                exit 1
            }
        }
        { $_ -eq "-s" -or $_ -eq "--max-size" } {
            if ($i + 1 -lt $args.Count) {
                $sizeStr = $args[$i + 1]
                if ($sizeStr -match '^(\d+)([KMG]?)$') {
                    $size = [int]$matches[1]
                    $suffix = $matches[2]
                    switch ($suffix) {
                        "K" { $MAX_FILE_SIZE = $size * 1KB }
                        "M" { $MAX_FILE_SIZE = $size * 1MB }
                        "G" { $MAX_FILE_SIZE = $size * 1GB }
                        default { $MAX_FILE_SIZE = $size }
                    }
                } else {
                    Write-Error "Invalid size format: $sizeStr"
                    exit 1
                }
                $i++
            } else {
                Write-Error "Missing value for $($args[$i])"
                exit 1
            }
        }
        { $_ -eq "-d" -or $_ -eq "--debug" } {
            $DEBUG = $true
        }
        { $_ -eq "-h" -or $_ -eq "--help" } {
            Show-Help
            exit 0
        }
        default {
            if ($args[$i].StartsWith("-")) {
                Write-Error "Unknown option: $($args[$i])"
                Show-Help
                exit 1
            } else {
                $SOURCE_DIR = $args[$i]
            }
        }
    }
}

# Convert to absolute path
 $SOURCE_DIR = Resolve-Path $SOURCE_DIR -ErrorAction SilentlyContinue
if (-not $SOURCE_DIR) {
    Write-Error "Error: Source directory does not exist: $SOURCE_DIR"
    exit 1
}
 $SOURCE_DIR = $SOURCE_DIR.Path

# Read .gitignore file and add to ignore patterns
 $IGNORE_PATTERNS = $DEFAULT_IGNORE_PATTERNS.Clone()
 $gitignorePath = Join-Path $SOURCE_DIR ".gitignore"
if (Test-Path $gitignorePath) {
    Get-Content $gitignorePath | ForEach-Object {
        # Skip empty lines and comments
        if ($_ -and $_.Trim() -and -not $_.Trim().StartsWith("#")) {
            $IGNORE_PATTERNS += $_.Trim()
        }
    }
}

# Merge exclude patterns
 $ALL_IGNORE_PATTERNS = $IGNORE_PATTERNS + $EXCLUDE_PATTERNS

# Debug function
function Debug-Message {
    param([string]$Message)
    if ($DEBUG) {
        Write-Host "DEBUG: $Message" -ForegroundColor Yellow
    }
}

# Check if file extension is a text file
function Is-TextExtension {
    param([string]$File)
    
    $extension = [System.IO.Path]::GetExtension($File).TrimStart('.')
    $filename = [System.IO.Path]::GetFileName($File).ToLower()
    
    # Check against known text file extensions
    foreach ($ext in $TEXT_FILE_EXTENSIONS) {
        if ($extension -eq $ext -or $filename -eq $ext) {
            return $true
        }
    }
    
    return $false
}

# Convert Jupyter notebook to markdown
function Convert-IpynbToMarkdown {
    param([string]$File)
    
    # Try using nbconvert if available
    try {
        $jupyter = Get-Command jupyter -ErrorAction SilentlyContinue
        if ($jupyter) {
            $result = & jupyter nbconvert --to markdown --stdout $File 2>$null
            if ($LASTEXITCODE -eq 0) {
                return $result
            }
        }
    } catch {
        Debug-Message "Failed to run jupyter nbconvert: $_"
    }
    
    # Try using nbconvert directly
    try {
        $jupyterNbconvert = Get-Command jupyter-nbconvert -ErrorAction SilentlyContinue
        if ($jupyterNbconvert) {
            $result = & jupyter-nbconvert --to markdown --stdout $File 2>$null
            if ($LASTEXITCODE -eq 0) {
                return $result
            }
        }
    } catch {
        Debug-Message "Failed to run jupyter-nbconvert: $_"
    }
    
    # Fallback: parse JSON manually using jq if available
    try {
        $jq = Get-Command jq -ErrorAction SilentlyContinue
        if ($jq) {
            $result = & jq -r '.cells[] | 
                if .cell_type == "markdown" then
                    "# Markdown Cell\n" + (.source | join("")) + "\n"
                elif .cell_type == "code" then
                    "# Code Cell\n```python\n" + (.source | join("")) + "\n```\n" +
                    if .outputs | length > 0 then
                        "# Output\n" + (
                            .outputs[] | 
                            if .text then
                                (.text | join(""))
                            elif .data then
                                (.data["text/plain"] // [] | join(""))
                            else
                                ""
                            end
                        ) + "\n"
                    else
                        ""
                    end
                else
                    ""
                end
            ' $File 2>$null
            
            if ($LASTEXITCODE -eq 0 -and $result) {
                return $result
            }
        }
    } catch {
        Debug-Message "Failed to parse with jq: $_"
    }
    
    # If neither nbconvert nor jq is available, just return failure
    return $null
}

# Check if file is binary using multiple methods
function Is-Binary {
    param([string]$File)
    
    if (-not (Test-Path $File -PathType Leaf)) {
        return $false
    }
    
    # Check file size first
    $fileSize = (Get-Item $File).Length
    if ($fileSize -gt $MAX_FILE_SIZE) {
        Debug-Message "File $File is too large ($fileSize bytes > $MAX_FILE_SIZE bytes)"
        return $true
    }
    
    # Check if it's a known text file extension or filename
    if (Is-TextExtension $File) {
        Debug-Message "File $File has text extension"
        return $false
    }
    
    # Check file extension against common binary extensions
    $extension = [System.IO.Path]::GetExtension($File).TrimStart('.')
    switch ($extension) {
        { $_ -in @("mp4", "avi", "mov", "mkv", "jpg", "jpeg", "png", "gif", "bmp", "svg", "ico", "pdf", "zip", "tar", "gz", "rar", "exe", "dll", "so", "dylib", "bin", "dat", "pt", "pth", "pkl", "pickle", "wandb", "model", "ckpt", "checkpoint", "safetensors") } {
            Debug-Message "File $File is binary (extension: $extension)"
            return $true
        }
    }
    
    # Use file command to detect file type (if available on Windows)
    try {
        $fileCmd = Get-Command file -ErrorAction SilentlyContinue
        if ($fileCmd) {
            $fileType = & file -b --mime-type $File 2>$null
            if ($fileType -eq "application/octet-stream" -or 
                ($fileType.StartsWith("application/") -and $fileType -notin @("application/json", "application/xml", "application/x-yaml", "application/x-tex")) -or
                $fileType.StartsWith("image/") -or 
                $fileType.StartsWith("video/") -or 
                $fileType.StartsWith("audio/")) {
                Debug-Message "File $File is binary (mime type: $fileType)"
                return $true
            }
        }
    } catch {
        Debug-Message "Failed to run file command: $_"
    }
    
    # Fallback: check if file contains null bytes
    try {
        $bytes = [System.IO.File]::ReadAllBytes($File)
        if ($bytes.Length -gt 1024) {
            $bytes = $bytes[0..1023]
        }
        if ($bytes -contains 0) {
            Debug-Message "File $File is binary (contains null bytes)"
            return $true
        }
    } catch {
        Debug-Message "Failed to read file for binary check: $_"
    }
    
    return $false
}

# Check if path matches any pattern
function Matches-Pattern {
    param([string]$Path, [string[]]$Patterns)
    
    $relPath = $Path.Replace($SOURCE_DIR, "").TrimStart("\", "/")
    
    foreach ($pattern in $Patterns) {
        # Handle directory patterns (ending with /)
        if ($pattern.EndsWith("/")) {
            $dirPattern = $pattern.TrimEnd("/")
            if ($relPath -like "$dirPattern/*" -or $relPath -eq $dirPattern) {
                Debug-Message "Path $relPath matches directory pattern $pattern"
                return $true
            }
        }
        
        # Handle glob patterns
        if ($relPath -like $pattern) {
            Debug-Message "Path $relPath matches pattern $pattern"
            return $true
        }
    }
    
    return $false
}

# Check if file should be ignored
function Should-Ignore {
    param([string]$Path)
    
    # Check if path contains .git directory
    if ($Path -like "*\.git*") {
        Debug-Message "Path $Path contains .git directory"
        return $true
    }
    
    # Check against ignore patterns
    if (Matches-Pattern $Path $ALL_IGNORE_PATTERNS) {
        return $true
    }
    
    # Check if file is binary
    if ((Test-Path $Path -PathType Leaf) -and (Is-Binary $Path)) {
        return $true
    }
    
    return $false
}

# Check if file should be included
function Should-Include {
    param([string]$Path)
    
    # If no include patterns specified, include all files
    if ($INCLUDE_PATTERNS.Count -eq 0) {
        return $true
    }
    
    return (Matches-Pattern $Path $INCLUDE_PATTERNS)
}

# Generate directory tree structure
function Generate-Tree {
    param([string]$Dir, [string]$Prefix)
    
    # Get entries in directory and sort them
    $entries = Get-ChildItem $Dir -Force | Where-Object { 
        -not (Should-Ignore $_.FullName) -and (Should-Include $_.FullName) 
    } | Sort-Object Name
    
    $count = $entries.Count
    $i = 0
    
    foreach ($entry in $entries) {
        $i++
        $name = $entry.Name
        $isLast = ($i -eq $count)
        $newPrefix = $Prefix
        
        if ($isLast) {
            Write-Host "$Prefix└── $name"
            $newPrefix = "$Prefix    "
        } else {
            Write-Host "$Prefix├── $name"
            $newPrefix = "$Prefix│   "
        }
        
        if ($entry.PSIsContainer) {
            Generate-Tree $entry.FullName $newPrefix
        }
    }
}

# Create temporary files
 $TREE_FILE = [System.IO.Path]::GetTempFileName()
 $CONTENT_FILE = [System.IO.Path]::GetTempFileName()
 $COUNT_FILE = [System.IO.Path]::GetTempFileName()
 $DEBUG_FILE = [System.IO.Path]::GetTempFileName()

# Generate directory tree
"Directory structure:" | Out-File -FilePath $TREE_FILE -Encoding UTF8
(Get-Item $SOURCE_DIR).Name | Out-File -FilePath $TREE_FILE -Encoding UTF8 -Append
Generate-Tree $SOURCE_DIR "" | Out-File -FilePath $TREE_FILE -Encoding UTF8 -Append

# Initialize counters
"0" | Out-File -FilePath $COUNT_FILE -Encoding UTF8
"0" | Out-File -FilePath $COUNT_FILE -Encoding UTF8 -Append

# Process file contents
"File processing log:" | Out-File -FilePath $DEBUG_FILE -Encoding UTF8

Get-ChildItem -Path $SOURCE_DIR -Recurse -File | ForEach-Object {
    $file = $_.FullName
    $relPath = $file.Replace($SOURCE_DIR, "").TrimStart("\", "/")
    
    if (Should-Ignore $file) {
        "IGNORED: $relPath" | Out-File -FilePath $DEBUG_FILE -Encoding UTF8 -Append
        return
    }
    
    if (-not (Should-Include $file)) {
        "NOT INCLUDED: $relPath" | Out-File -FilePath $DEBUG_FILE -Encoding UTF8 -Append
        return
    }
    
    "PROCESSING: $relPath" | Out-File -FilePath $DEBUG_FILE -Encoding UTF8 -Append
    
    # Count lines
    try {
        $lines = (Get-Content $file -Encoding UTF8 | Measure-Object -Line).Lines
    } catch {
        $lines = 0
    }
    
    # Update counters
    $counts = Get-Content $COUNT_FILE
    $fileCount = [int]$counts[0]
    $lineCount = [int]$counts[1]
    ($fileCount + 1).ToString() | Out-File -FilePath $COUNT_FILE -Encoding UTF8
    ($lineCount + $lines).ToString() | Out-File -FilePath $COUNT_FILE -Encoding UTF8 -Append
    
    # Add file content with proper encoding handling
    @"
================================================
FILE: $relPath
================================================
"@ | Out-File -FilePath $CONTENT_FILE -Encoding UTF8 -Append
    
    # Special handling for Jupyter notebooks
    if ([System.IO.Path]::GetExtension($file) -eq ".ipynb") {
        $notebookContent = Convert-IpynbToMarkdown $file
        if ($notebookContent) {
            $notebookContent | Out-File -FilePath $CONTENT_FILE -Encoding UTF8 -Append
        } else {
            # If conversion failed, just dump the raw content
            try {
                Get-Content $file -Encoding UTF8 | Out-File -FilePath $CONTENT_FILE -Encoding UTF8 -Append
            } catch {
                try {
                    Get-Content $file -Encoding UTF7 | Out-File -FilePath $CONTENT_FILE -Encoding UTF8 -Append
                } catch {
                    try {
                        Get-Content $file | Out-File -FilePath $CONTENT_FILE -Encoding UTF8 -Append
                    } catch {
                        # Last resort - just read as bytes and convert
                        $bytes = [System.IO.File]::ReadAllBytes($file)
                        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
                        $text | Out-File -FilePath $CONTENT_FILE -Encoding UTF8 -Append
                    }
                }
            }
        }
    } else {
        # Convert file content to UTF-8, removing any problematic characters
        try {
            Get-Content $file -Encoding UTF8 | Out-File -FilePath $CONTENT_FILE -Encoding UTF8 -Append
        } catch {
            try {
                Get-Content $file -Encoding UTF7 | Out-File -FilePath $CONTENT_FILE -Encoding UTF8 -Append
            } catch {
                try {
                    Get-Content $file | Out-File -FilePath $CONTENT_FILE -Encoding UTF8 -Append
                } catch {
                    # Last resort - just read as bytes and convert
                    $bytes = [System.IO.File]::ReadAllBytes($file)
                    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
                    $text | Out-File -FilePath $CONTENT_FILE -Encoding UTF8 -Append
                }
            }
        }
    }
    
    "" | Out-File -FilePath $CONTENT_FILE -Encoding UTF8 -Append
}

# Read final counts
 $counts = Get-Content $COUNT_FILE
 $FILE_COUNT = [int]$counts[0]
 $LINE_COUNT = [int]$counts[1]

# Generate summary
 $SUMMARY = @"
Summary:
--------
Total files: $FILE_COUNT
Total lines: $LINE_COUNT
Max file size: $MAX_FILE_SIZE bytes
"@

# Output results
if ($OUTPUT_FILE -eq "-") {
    Write-Host $SUMMARY
    Get-Content $TREE_FILE
    Write-Host ""
    Get-Content $CONTENT_FILE
} else {
    $SUMMARY | Out-File -FilePath $OUTPUT_FILE -Encoding UTF8
    Get-Content $TREE_FILE | Out-File -FilePath $OUTPUT_FILE -Encoding UTF8 -Append
    "" | Out-File -FilePath $OUTPUT_FILE -Encoding UTF8 -Append
    Get-Content $CONTENT_FILE | Out-File -FilePath $OUTPUT_FILE -Encoding UTF8 -Append
    Write-Host "Analysis complete! Output written to: $OUTPUT_FILE"
}

# Show debug information if requested
if ($DEBUG) {
    Write-Host "Debug information:" -ForegroundColor Yellow
    Get-Content $DEBUG_FILE | Write-Host
}

# Clean up temporary files
Remove-Item $TREE_FILE, $CONTENT_FILE, $COUNT_FILE, $DEBUG_FILE -ErrorAction SilentlyContinue