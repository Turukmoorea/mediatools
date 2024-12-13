#!/bin/bash

# Default values for source and destination directories
# Default source is the current directory
# Default destination is ./extracted
default_source="."
default_destination="./extracted"
already_extracted_dir="" # Directory for already processed files, to be set dynamically in the source directory

# Variables for user-provided directories
source_dir="$default_source"
destination_dir="$default_destination"
remove_files=false # Flag to determine if original files should be deleted
specific_file=""  # Holds the specific file to process if provided

# Function: Display help
# Outputs usage instructions and exits
function display_help {
    echo "Usage: $0 -s [source_directory] -d [destination_directory] -f [specific_file] -o [options]"
    echo
    echo "Description:"
    echo "This script extracts compressed files from the specified source directory to a specified destination directory."
    echo "If no source directory is provided, it defaults to the current directory."
    echo "If no destination directory is provided, it defaults to './extracted'."
    echo
    echo "Options:"
    echo "  -h                 Show this help message and exit"
    echo "  -s [source]        Specify the source directory (default: current directory)"
    echo "  -d [destination]   Specify the destination directory (default: './extracted')"
    echo "  -f [file]          Specify a specific file or multi-part archive to extract"
    echo "  -r, --remove       Remove the original compressed file after extraction"
    echo
    echo "Beschreibung:"
    echo "Dieses Skript entpackt komprimierte Dateien aus dem angegebenen Quellverzeichnis in ein Zielverzeichnis."
    echo "Wird kein Quellverzeichnis angegeben, wird standardmäßig das aktuelle Verzeichnis verwendet."
    echo "Wird kein Zielverzeichnis angegeben, wird standardmäßig './extracted' verwendet."
    echo
    echo "Optionen:"
    echo "  -h                 Zeige diese Hilfe an und beende das Skript"
    echo "  -s [Quelle]        Gebe das Quellverzeichnis an (Standard: aktuelles Verzeichnis)"
    echo "  -d [Ziel]          Gebe das Zielverzeichnis an (Standard: './extracted')"
    echo "  -f [Datei]         Gebe eine spezifische Datei oder ein mehrteiliges Archiv an, das entpackt werden soll"
    echo "  -r, --remove       Entferne die ursprüngliche komprimierte Datei nach dem Entpacken"
    echo
    exit 0
}

# Parse arguments
# Loop through the provided arguments and set variables or display help
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h)
            display_help
            ;;
        -s)
            source_dir="$2"
            shift 2
            ;;
        -d)
            destination_dir="$2"
            shift 2
            ;;
        -f)
            specific_file="$2"
            shift 2
            ;;
        -r|--remove)
            remove_files=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            display_help
            ;;
    esac
done

# Set the already_extracted_dir dynamically in the source directory
already_extracted_dir="$source_dir/already_extracted_originals"
processed_archives=() # Array to track processed archives

# Function: Check and install required tools
# Verifies if a required tool is installed, and prompts for installation if missing
function check_and_install {
    tool="$1"
    if ! command -v "$tool" &> /dev/null; then
        echo "$tool is not installed. Would you like to install it? [y/N]"
        read -t 60 install_tool
        if [[ "$install_tool" == "y" || "$install_tool" == "Y" ]]; then
            sudo apt update && sudo apt install -y "$tool"
        else
            echo "$tool will be skipped."
            return 1
        fi
    fi
    return 0
}

# Function: Extract the file
# Handles the extraction of a single file based on its extension
function extract_file {
    file="$1"
    ext="$2"
    echo "Extracting file: $file into $destination_dir..."
    case "$ext" in
        "zip")
            check_and_install "unzip" && unzip -o "$file" -d "$destination_dir" > /dev/null 2>&1
            ;;
        "tar.gz"|"tgz")
            check_and_install "tar" && tar -xvzf "$file" -C "$destination_dir" > /dev/null 2>&1
            ;;
        "tar.bz2")
            check_and_install "tar" && tar -xvjf "$file" -C "$destination_dir" > /dev/null 2>&1
            ;;
        "tar.xz")
            check_and_install "tar" && tar -xvJf "$file" -C "$destination_dir" > /dev/null 2>&1
            ;;
        "7z")
            check_and_install "p7zip-full" && 7z x "$file" -o"$destination_dir" > /dev/null 2>&1
            ;;
        "rar")
            check_and_install "unrar" && unrar x -o+ "$file" "$destination_dir" > /dev/null 2>&1
            ;;
        *)
            echo "File format $ext is not supported. Skipping the file."
            return
            ;;
    esac

    # Handle post-processing (delete or move original file)
    if $remove_files; then
        rm "$file"
    else
        if [ ! -d "$already_extracted_dir" ]; then
            mkdir -p "$already_extracted_dir"
        fi
        mv "$file" "$already_extracted_dir"
    fi
}

# Function: Handle multi-part archives (RAR, ZIP, etc.)
# Detects and extracts only the first part of a multi-part archive
function handle_multipart_archive {
    base_file="$1"
    ext="$2"
    archive_name="${base_file%.*}" # Base name without extensions

    # Skip processing if archive has already been extracted
    if [[ " ${processed_archives[@]} " =~ " $archive_name " ]]; then
        echo "Skipping already processed archive: $archive_name"
        return
    fi

    # Add to processed archives
    processed_archives+=("$archive_name")

    # Extract only the first part of multi-part archives
    if [[ "$base_file" =~ \.part[0-9]+\.$ext$ && ! "$base_file" =~ \.part1\.$ext$ ]]; then
        echo "Skipping non-first part of multi-part archive: $base_file"
        return
    fi

    echo "Extracting multi-part archive: $base_file into $destination_dir..."
    case "$ext" in
        "rar")
            check_and_install "unrar" && unrar x -o+ "$base_file" "$destination_dir" > /dev/null 2>&1
            ;;
        "zip")
            check_and_install "unzip" && unzip -o "$base_file" -d "$destination_dir" > /dev/null 2>&1
            ;;
        "7z")
            check_and_install "p7zip-full" && 7z x "$base_file" -o"$destination_dir" > /dev/null 2>&1
            ;;
        "tar.gz"|"tgz")
            check_and_install "tar" && tar -xvzf "$base_file" -C "$destination_dir" > /dev/null 2>&1
            ;;
        "tar.bz2")
            check_and_install "tar" && tar -xvjf "$base_file" -C "$destination_dir" > /dev/null 2>&1
            ;;
        "tar.xz")
            check_and_install "tar" && tar -xvJf "$base_file" -C "$destination_dir" > /dev/null 2>&1
            ;;
        *)
            echo "Multi-part handling not supported for file type: $ext"
            return
            ;;
    esac
    
# Handle post-processing for multi-part archives
    if $remove_files; then
        rm "${base_file%.*}"*  # Remove all parts of the archive
    else
        if [ ! -d "$already_extracted_dir" ]; then
            mkdir -p "$already_extracted_dir"
        fi
        mv "${base_file%.*}"* "$already_extracted_dir"  # Move all parts
    fi
}

# Ensure the destination directory exists
if [ ! -d "$destination_dir" ]; then
    mkdir -p "$destination_dir"
fi

# Verify source directory exists
if [ ! -d "$source_dir" ]; then
    echo "Source directory $source_dir does not exist. Exiting."
    exit 1
fi

# Process a specific file if provided
if [[ -n "$specific_file" ]]; then
    ext=$(echo "$specific_file" | grep -oE '\.[^./]+$' | sed 's/^\.//')
    if [[ "$specific_file" == *.part1.* || "$specific_file" == *.[a-z][0-9][0-9] ]]; then
        handle_multipart_archive "$specific_file" "$ext"
    else
        extract_file "$specific_file" "$ext"
    fi
    exit 0
fi

# Loop through files in the source directory and process them
if [ -z "$(ls -A "$source_dir")" ]; then
    echo "Source directory is empty. No files to process."
    exit 0
fi

for file in "$source_dir"/*; do
    if [ -f "$file" ]; then
        # Extract file extension
        extension=$(echo "$file" | grep -oE '\.[^./]+$' | sed 's/^\.//')
        
        # Handle multi-part extensions
        if [[ "$file" == *.part1.* || "$file" == *.[a-z][0-9][0-9] ]]; then
            handle_multipart_archive "$file" "$extension"
        else
            # Extract the file
            extract_file "$file" "$extension"
        fi
    fi

done

