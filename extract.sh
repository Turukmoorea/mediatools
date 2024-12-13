#!/bin/bash

# Default values for source and destination directories
# Default source is the current directory
# Default destination is ./extracted
default_source="."
default_destination="./extracted"
already_extracted_dir="./already_extracted_originals" # Directory for already processed files

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
    case "$ext" in
        "zip")
            check_and_install "unzip" && unzip "$file" -d "$destination_dir"
            ;;
        "tar.gz"|"tgz")
            check_and_install "tar" && tar -xvzf "$file" -C "$destination_dir"
            ;;
        "tar.bz2")
            check_and_install "tar" && tar -xvjf "$file" -C "$destination_dir"
            ;;
        "tar.xz")
            check_and_install "tar" && tar -xvJf "$file" -C "$destination_dir"
            ;;
        "7z")
            check_and_install "p7zip-full" && 7z x "$file" -o"$destination_dir"
            ;;
        "rar")
            check_and_install "unrar" && unrar x "$file" "$destination_dir"
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
# Detects and extracts all parts of a multi-part archive
function handle_multipart_archive {
    base_file="$1"
    ext="$2"
    case "$ext" in
        "rar")
            check_and_install "unrar" && unrar x "$base_file" "$destination_dir"
            ;;
        "zip")
            check_and_install "unzip" && unzip "$base_file" -d "$destination_dir"
            ;;
        "7z")
            check_and_install "p7zip-full" && 7z x "$base_file" -o"$destination_dir"
            ;;
        "tar.gz"|"tgz")
            check_and_install "tar" && tar -xvzf "$base_file" -C "$destination_dir"
            ;;
        "tar.bz2")
            check_and_install "tar" && tar -xvjf "$base_file" -C "$destination_dir"
            ;;
        "tar.xz")
            check_and_install "tar" && tar -xvJf "$base_file" -C "$destination_dir"
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

