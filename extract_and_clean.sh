#!/bin/bash

# Default values for source and destination directories
default_source="."
default_destination="./extracted"
already_extracted_dir="./already_extracted_originals"

# Variables for user-provided directories
source_dir="$default_source"
destination_dir="$default_destination"
remove_files=false

# Function: Display help
function display_help {
    echo "Usage: $0 -s [source_directory] -d [destination_directory] -o [options]"
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
    echo "  -r, --remove       Remove the original compressed file after extraction"
    echo
    echo "Beschreibung"
    echo "Dieses Skript entpackt komprimierte Dateien aus dem angegebenen Quellverzeichnis in ein Zielverzeichnis."
    echo "Wird kein Quellverzeichnis angegeben, wird standardmäßig das aktuelle Verzeichnis verwendet."
    echo "Wird kein Zielverzeichnis angegeben, wird standardmäßig './extracted' verwendet."
    echo "Optionen:"
    echo "  -h                 Show this help message and exit"
    echo "  -s [source]        Specify the source directory (default: current directory)"
    echo "  -d [destination]   Specify the destination directory (default: './extracted')"
    echo "  -r, --remove       Entfernt die ursprüngliche komprimierte Datei nach dem Entpacken"
    echo
    exit 0
}

# Parse arguments
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

    if $remove_files; then
        rm "$file"
    else
        if [ ! -d "$already_extracted_dir" ]; then
            mkdir -p "$already_extracted_dir"
        fi
        mv "$file" "$already_extracted_dir"
    fi
}

# Check if destination directory exists, create it if not
if [ ! -d "$destination_dir" ]; then
    mkdir -p "$destination_dir"
fi

# Check if source directory exists
if [ ! -d "$source_dir" ]; then
    echo "Source directory $source_dir does not exist. Exiting."
    exit 1
fi

# Analyze and process files in the source directory
for file in "$source_dir"/*; do
    if [ -f "$file" ]; then
        # Extract file extension
        extension=$(echo "$file" | grep -oE '\.[^./]+$' | sed 's/^\.//')
        
        # Special handling for multi-part extensions like tar.gz
        if [[ "$file" == *.tar.gz ]]; then
            extension="tar.gz"
        elif [[ "$file" == *.tar.bz2 ]]; then
            extension="tar.bz2"
        elif [[ "$file" == *.tar.xz ]]; then
            extension="tar.xz"
        fi

        # Extract the file
        extract_file "$file" "$extension"
    fi
done

