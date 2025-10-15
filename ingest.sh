#!/bin/bash

# Default ignore patterns for files and directories
DEFAULT_IGNORE_PATTERNS=(
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
MAX_FILE_SIZE=$((1024 * 1024))  # 1MB default max file size
TEXT_FILE_EXTENSIONS=("py" "js" "ts" "java" "cpp" "c" "h" "hpp" "cs" "php" "rb" "go" "rs" "swift" "kt" "scala" "sh" "bash" "zsh" "fish" "ps1" "bat" "cmd" "html" "htm" "css" "scss" "sass" "less" "xml" "json" "yaml" "yml" "toml" "ini" "cfg" "conf" "md" "txt" "rst" "tex" "sql" "r" "m" "pl" "lua" "vim" "dockerfile" "makefile" "cmake" "requirements.txt" "setup.py" "package.json" "tsconfig.json" "webpack.config.js" "babel.config.js" ".eslintrc.js" ".prettierrc" "gitignore" "gitattributes" "editorconfig" "license" "readme" "changelog" "contributing" "install" "news" "authors" "history" "todo" "faq" "security" "conduct" "changes" "version" "manifest" "metadata" "diff" "patch" "ipynb")

# Show help information
show_help() {
    echo "Usage: $0 [options] [source directory]"
    echo ""
    echo "Options:"
    echo "  -o, --output FILE     Output file path (default: digest.txt, use '-' for stdout)"
    echo "  -i, --include PATTERN Include files matching pattern (can be used multiple times)"
    echo "  -e, --exclude PATTERN Exclude files matching pattern (can be used multiple times)"
    echo "  -s, --max-size SIZE   Maximum file size in bytes (default: 1MB)"
    echo "  --no-gitignore        Do not use patterns from .gitignore for exclusion" 
    echo "  -d, --debug           Enable debug output"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 /path/to/project"
    echo "  $0 -o summary.txt -i \"*.py\" -i \"*.js\" /path/to/project"
    echo "  $0 --output - /path/to/project  # Output to stdout"
    echo "  $0 -s 2M /path/to/project  # Set max file size to 2MB"
}

# Parse command line arguments
OUTPUT_FILE="digest.txt"
SOURCE_DIR="."
INCLUDE_PATTERNS=()
EXCLUDE_PATTERNS=()
USE_GITIGNORE=true
DEBUG=false



while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -i|--include)
            INCLUDE_PATTERNS+=("$2")
            shift 2
            ;;
        -e|--exclude)
            EXCLUDE_PATTERNS+=("$2")
            shift 2
            ;;
        -s|--max-size)
            # Parse size with optional suffix (K, M, G)
            if [[ "$2" =~ ^([0-9]+)([KMG]?)$ ]]; then
                size="${BASH_REMATCH[1]}"
                suffix="${BASH_REMATCH[2]}"
                case "$suffix" in
                    K) MAX_FILE_SIZE=$((size * 1024)) ;;
                    M) MAX_FILE_SIZE=$((size * 1024 * 1024)) ;;
                    G) MAX_FILE_SIZE=$((size * 1024 * 1024 * 1024)) ;;
                    *) MAX_FILE_SIZE=$size ;;
                esac
            else
                echo "Error: Invalid size format: $2" >&2
                exit 1
            fi
            shift 2
            ;;

        --no-gitignore)
            USE_GITIGNORE=false
            shift
            ;;

        -d|--debug)
            DEBUG=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            SOURCE_DIR="$1"
            shift
            ;;
    esac
done

# Debug function
debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo "DEBUG: $1" >&2
    fi
}


# Convert to absolute path
SOURCE_DIR=$(realpath "$SOURCE_DIR")

# Resolve output file absolute path (if not stdout)
OUTPUT_ABS=""
if [[ "$OUTPUT_FILE" != "-" ]]; then
    OUTPUT_ABS=$(realpath -m "$OUTPUT_FILE" 2>/dev/null || echo "")
fi

# Check if source directory exists
if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Error: Source directory does not exist: $SOURCE_DIR" >&2
    exit 1
fi

# Read .gitignore file and add to ignore patterns
IGNORE_PATTERNS=("${DEFAULT_IGNORE_PATTERNS[@]}")
if [[ "$USE_GITIGNORE" == "true" ]]; then
    if [[ -f "$SOURCE_DIR/.gitignore" ]]; then
        debug "Using patterns from .gitignore"
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Strip trailing CR (for CRLF files) and trim leading/trailing whitespace
            line="${line%$'\r'}"
            line="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
            # Skip empty lines and comments
            if [[ -n "$line" && ! "$line" =~ ^# ]]; then
                IGNORE_PATTERNS+=("$line")
            fi
        done < "$SOURCE_DIR/.gitignore"
    fi
else
    debug "Ignoring .gitignore file as requested"
fi

# Merge exclude patterns
ALL_IGNORE_PATTERNS=("${IGNORE_PATTERNS[@]}" "${EXCLUDE_PATTERNS[@]}")


# Check if file extension is a text file
is_text_extension() {
    local file="$1"
    local extension="${file##*.}"
    local filename=$(basename "$file" | tr '[:upper:]' '[:lower:]')
    
    # Check against known text file extensions
    for ext in "${TEXT_FILE_EXTENSIONS[@]}"; do
        if [[ "$extension" == "$ext" || "$filename" == "$ext" ]]; then
            return 0
        fi
    done
    
    return 1
}

# Convert Jupyter notebook to markdown
convert_ipynb_to_markdown() {
    local file="$1"
    
    # Try using nbconvert if available
    if command -v jupyter >/dev/null 2>&1; then
        jupyter nbconvert --to markdown --stdout "$file" 2>/dev/null
        return $?
    fi
    
    # Try using nbconvert directly
    if command -v jupyter-nbconvert >/dev/null 2>&1; then
        jupyter-nbconvert --to markdown --stdout "$file" 2>/dev/null
        return $?
    fi
    
    # Fallback: parse JSON manually using jq if available
    if command -v jq >/dev/null 2>&1; then
        local cells=$(jq -r '.cells[] | 
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
        ' "$file" 2>/dev/null)
        
        if [[ $? -eq 0 && -n "$cells" ]]; then
            echo "$cells"
            return 0
        fi
    fi
    
    # If neither nbconvert nor jq is available, just dump the raw content
    return 1
}

# Check if file is binary using multiple methods
is_binary() {
    local file="$1"
    local file_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
    
    # Check file size first
    if [[ $file_size -gt $MAX_FILE_SIZE ]]; then
        debug "File $file is too large ($file_size bytes > $MAX_FILE_SIZE bytes)"
        return 0
    fi
    
    # Check if it's a known text file extension or filename
    if is_text_extension "$file"; then
        debug "File $file has text extension"
        return 1
    fi
    
    # Check file extension against common binary extensions
    local extension="${file##*.}"
    case "$extension" in
        mp4|avi|mov|mkv|jpg|jpeg|png|gif|bmp|svg|ico|pdf|zip|tar|gz|rar|exe|dll|so|dylib|bin|dat|pt|pth|pkl|pickle|wandb|model|ckpt|checkpoint|safetensors)
            debug "File $file is binary (extension: $extension)"
            return 0
            ;;
    esac
    
    # Use file command to detect file type
    if command -v file >/dev/null 2>&1; then
        local file_type=$(file -b --mime-type "$file" 2>/dev/null)
        # Treat most application/* (except common text-y ones) and any image/*, video/*, audio/* as binary
        if [[ $file_type == "application/octet-stream" ]] || \
           [[ $file_type == image/* ]] || [[ $file_type == video/* ]] || [[ $file_type == audio/* ]] || \
           ( [[ $file_type == application/* ]] && [[ $file_type != application/json ]] && [[ $file_type != application/xml ]] && [[ $file_type != application/x-yaml ]] && [[ $file_type != application/x-tex ]] ); then
            debug "File $file is binary (mime type: $file_type)"
            return 0
        fi
    else
        # Fallback: check if file contains null bytes
        if head -c 1024 "$file" 2>/dev/null | grep -q $'\0'; then
            debug "File $file is binary (contains null bytes)"
            return 0
        fi
    fi
    
    return 1
}

# Check if path matches any pattern
matches_pattern() {
    local path="$1"
    shift
    local patterns=("$@")

    for pattern in "${patterns[@]}"; do
        # Convert path to relative path
        local rel_path="${path#$SOURCE_DIR/}"

        # Normalize pattern: strip leading './' and leading '/'
        local pat="$pattern"
        [[ "$pat" == ./* ]] && pat="${pat#./}"
        [[ "$pat" == /* ]] && pat="${pat#/}"

        # Handle directory patterns (ending with /)
        if [[ "$pat" == */ ]]; then
            local dir_pattern="${pat%/}"
            if [[ "$rel_path" == "$dir_pattern"/* || "$rel_path" == "$dir_pattern" ]]; then
                debug "Path $rel_path matches directory pattern $pattern"
                return 0
            fi
        fi

        # Handle glob patterns
        if [[ "$rel_path" == $pat ]]; then
            debug "Path $rel_path matches pattern $pattern"
            return 0
        fi
    done
    return 1
}

# Check if file should be ignored
is_ignored() {
    local path="$1"
    
    # Always ignore the output file itself (default or custom -o)
    if [[ -n "$OUTPUT_ABS" ]]; then
        # Compare absolute paths; entries discovered by find are absolute
        if [[ "$path" == "$OUTPUT_ABS" ]]; then
            debug "Path $path is the output file; excluding"
            return 0
        fi
    fi

    # If include patterns are specified and the path matches one, do NOT ignore it.
    # This gives `-i` precedence over ignore rules.
    if [[ ${#INCLUDE_PATTERNS[@]} -gt 0 ]] && matches_pattern "$path" "${INCLUDE_PATTERNS[@]}"; then
        debug "Path $path is explicitly included, overriding ignore rules."
        return 1 # Not ignored (in Bash, 1 is a "false" exit code)
    fi

    # Check if path contains .git directory
    if [[ "$path" == *".git"* ]]; then
        debug "Path $path contains .git directory"
        return 0
    fi
    
    # Check against ignore patterns
    if matches_pattern "$path" "${ALL_IGNORE_PATTERNS[@]}"; then
        return 0
    fi
    
    # Check if file is binary
    if [[ -f "$path" ]] && is_binary "$path"; then
        return 0
    fi
    
    return 1
}

# Check if file should be included
is_included() {
    local path="$1"
    
    # If no include patterns specified, include all files
    if [[ ${#INCLUDE_PATTERNS[@]} -eq 0 ]]; then
        return 0
    fi
    
    matches_pattern "$path" "${INCLUDE_PATTERNS[@]}"
}

# Generate directory tree structure
generate_tree() {
    local dir="$1"
    local prefix="$2"
    
    # Get entries in directory and sort them
    local entries=()
    while IFS= read -r -d $'\0' entry; do
        if ! is_ignored "$entry" && is_included "$entry"; then
            entries+=("$entry")
        fi
    done < <(find "$dir" -maxdepth 1 -mindepth 1 -print0 | sort -z)
    
    local count=${#entries[@]}
    local i=0
    
    for entry in "${entries[@]}"; do
        i=$((i+1))
        local name=$(basename "$entry")
        local is_last=$((i == count))
        local new_prefix="$prefix"
        
        if [[ $is_last -eq 1 ]]; then
            echo "${prefix}└── $name"
            new_prefix="${prefix}    "
        else
            echo "${prefix}├── $name"
            new_prefix="${prefix}│   "
        fi
        
        if [[ -d "$entry" ]]; then
            generate_tree "$entry" "$new_prefix"
        fi
    done
}

# Create temporary files
TREE_FILE=$(mktemp)
CONTENT_FILE=$(mktemp)
COUNT_FILE=$(mktemp)
DEBUG_FILE=$(mktemp)

# Generate directory tree
echo "Directory structure:" > "$TREE_FILE"
echo "$(basename "$SOURCE_DIR")" >> "$TREE_FILE"
generate_tree "$SOURCE_DIR" "" >> "$TREE_FILE"

# Initialize counters
echo "0" > "$COUNT_FILE"  # Total files
echo "0" >> "$COUNT_FILE" # Total lines

# Process file contents
echo "File processing log:" > "$DEBUG_FILE"
find "$SOURCE_DIR" -type f -print0 | while IFS= read -r -d $'\0' file; do
    rel_path="${file#$SOURCE_DIR/}"
    
    if is_ignored "$file"; then
        echo "IGNORED: $rel_path" >> "$DEBUG_FILE"
        continue
    fi
    
    if ! is_included "$file"; then
        echo "NOT INCLUDED: $rel_path" >> "$DEBUG_FILE"
        continue
    fi
    
    echo "PROCESSING: $rel_path" >> "$DEBUG_FILE"
    
    # Count lines (handle potential errors)
    lines=$(wc -l < "$file" 2>/dev/null || echo "0")
    
    # Update counters
    file_count=$(head -n 1 "$COUNT_FILE")
    line_count=$(tail -n 1 "$COUNT_FILE")
    echo $((file_count + 1)) > "$COUNT_FILE"
    echo $((line_count + lines)) >> "$COUNT_FILE"
    
    # Add file content with proper encoding handling
    {
        echo "================================================"
        echo "FILE: $rel_path"
        echo "================================================"
        
        # Special handling for Jupyter notebooks
        if [[ "${file##*.}" == "ipynb" ]]; then
            if ! convert_ipynb_to_markdown "$file"; then
                # If conversion failed, just dump the raw content
                iconv -f UTF-8 -t UTF-8 -c "$file" 2>/dev/null || \
                iconv -f CP1252 -t UTF-8 -c "$file" 2>/dev/null || \
                iconv -f ISO-8859-1 -t UTF-8 -c "$file" 2>/dev/null || \
                cat "$file" 2>/dev/null
            fi
        else
            # Convert file content to UTF-8, removing any problematic characters
            iconv -f UTF-8 -t UTF-8 -c "$file" 2>/dev/null || \
            iconv -f CP1252 -t UTF-8 -c "$file" 2>/dev/null || \
            iconv -f ISO-8859-1 -t UTF-8 -c "$file" 2>/dev/null || \
            cat "$file" 2>/dev/null
        fi
        echo
    } >> "$CONTENT_FILE"
done

# Read final counts
FILE_COUNT=$(head -n 1 "$COUNT_FILE")
LINE_COUNT=$(tail -n 1 "$COUNT_FILE")

# Generate summary
SUMMARY="Summary:
--------
Total files: $FILE_COUNT
Total lines: $LINE_COUNT
Max file size: $MAX_FILE_SIZE bytes
"

# Output results
if [[ "$OUTPUT_FILE" == "-" ]]; then
    echo "$SUMMARY"
    cat "$TREE_FILE"
    echo
    cat "$CONTENT_FILE"
else
    {
        echo "$SUMMARY"
        cat "$TREE_FILE"
        echo
        cat "$CONTENT_FILE"
    } > "$OUTPUT_FILE"
    echo "Analysis complete! Output written to: $OUTPUT_FILE"
fi

# Show debug information if requested
if [[ "$DEBUG" == "true" ]]; then
    echo "Debug information:" >&2
    cat "$DEBUG_FILE" >&2
fi

# Clean up temporary files
rm -f "$TREE_FILE" "$CONTENT_FILE" "$COUNT_FILE" "$DEBUG_FILE"