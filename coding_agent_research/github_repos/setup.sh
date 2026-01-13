#!/bin/bash

# GitHub Repositories Setup Script
# This script clones missing repositories and pulls the latest changes for existing ones

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Repository definitions
# Format: "directory_name|repository_url"
declare -a REPOS=(
    "aider|https://github.com/Aider-AI/aider.git"
    "cline|https://github.com/cline/cline.git"
    "codex|https://github.com/openai/codex.git"
    "continue|https://github.com/continuedev/continue.git"
    "gemini-cli|https://github.com/google-gemini/gemini-cli.git"
    "goose|https://github.com/block/goose.git"
    "kilocode|https://github.com/Kilo-Org/kilocode.git"
    "OpenHands|https://github.com/All-Hands-AI/OpenHands.git"
    "Roo-Code|https://github.com/RooCodeInc/Roo-Code.git"
)

# Function to check if git is installed
check_git() {
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed. Please install Git first."
        exit 1
    fi
}

# Function to clone a repository
clone_repo() {
    local dir_name="$1"
    local repo_url="$2"
    
    print_status "Cloning $dir_name from $repo_url..."
    if git clone "$repo_url" "$dir_name"; then
        print_success "Successfully cloned $dir_name"
    else
        print_error "Failed to clone $dir_name"
        return 1
    fi
}

# Function to update an existing repository
update_repo() {
    local dir_name="$1"
    local repo_url="$2"
    
    print_status "Updating $dir_name..."
    cd "$dir_name"
    
    # Check if it's a git repository
    if [ ! -d ".git" ]; then
        print_warning "$dir_name exists but is not a git repository"
        cd ..
        return 1
    fi
    
    # Check if remote origin matches expected URL
    local current_url=$(git remote get-url origin 2>/dev/null || echo "")
    if [ "$current_url" != "$repo_url" ]; then
        print_warning "$dir_name has different remote URL: $current_url (expected: $repo_url)"
        print_status "Updating remote URL..."
        git remote set-url origin "$repo_url"
    fi
    
    # Fetch latest changes
    if git fetch origin; then
        # Get current branch
        local current_branch=$(git rev-parse --abbrev-ref HEAD)
        local default_branch=""
        
        # Try to determine the default branch
        if git show-ref --verify --quiet refs/remotes/origin/main; then
            default_branch="main"
        elif git show-ref --verify --quiet refs/remotes/origin/master; then
            default_branch="master"
        else
            # Get the default branch from remote
            default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
        fi
        
        # Check if we're on the default branch
        if [ "$current_branch" = "$default_branch" ]; then
            # Check if there are uncommitted changes
            if git diff --quiet && git diff --staged --quiet; then
                print_status "Pulling latest changes for $dir_name..."
                if git pull origin "$default_branch"; then
                    print_success "Successfully updated $dir_name"
                else
                    print_error "Failed to pull changes for $dir_name"
                    cd ..
                    return 1
                fi
            else
                print_warning "$dir_name has uncommitted changes. Skipping pull."
                print_status "You can manually pull changes after committing or stashing your work."
            fi
        else
            print_warning "$dir_name is on branch '$current_branch', not '$default_branch'. Skipping pull."
            print_status "Switch to '$default_branch' branch if you want to pull latest changes."
        fi
    else
        print_error "Failed to fetch changes for $dir_name"
        cd ..
        return 1
    fi
    
    cd ..
}

# Function to process a single repository
process_repo() {
    local repo_info="$1"
    local dir_name=$(echo "$repo_info" | cut -d'|' -f1)
    local repo_url=$(echo "$repo_info" | cut -d'|' -f2)
    
    echo
    print_status "Processing repository: $dir_name"
    
    if [ -d "$dir_name" ]; then
        update_repo "$dir_name" "$repo_url"
    else
        clone_repo "$dir_name" "$repo_url"
    fi
}

# Main function
main() {
    print_status "Starting GitHub repositories setup..."
    print_status "Working directory: $(pwd)"
    
    # Check if git is available
    check_git
    
    # Process each repository
    local success_count=0
    local total_count=${#REPOS[@]}
    
    for repo in "${REPOS[@]}"; do
        if process_repo "$repo"; then
            ((success_count++))
        fi
    done
    
    echo
    print_status "Setup completed!"
    print_success "Successfully processed $success_count out of $total_count repositories"
    
    if [ $success_count -lt $total_count ]; then
        print_warning "Some repositories failed to process. Check the output above for details."
        exit 1
    fi
}

# Help function
show_help() {
    echo "GitHub Repositories Setup Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "This script manages the following repositories:"
    for repo in "${REPOS[@]}"; do
        local dir_name=$(echo "$repo" | cut -d'|' -f1)
        local repo_url=$(echo "$repo" | cut -d'|' -f2)
        echo "  - $dir_name: $repo_url"
    done
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -l, --list     List all repositories"
    echo
    echo "The script will:"
    echo "  - Clone repositories that don't exist locally"
    echo "  - Pull latest changes for existing repositories (if on default branch with no uncommitted changes)"
    echo "  - Update remote URLs if they don't match the expected ones"
    echo
}

# List repositories function
list_repos() {
    echo "Configured repositories:"
    for repo in "${REPOS[@]}"; do
        local dir_name=$(echo "$repo" | cut -d'|' -f1)
        local repo_url=$(echo "$repo" | cut -d'|' -f2)
        local status="NOT FOUND"
        if [ -d "$dir_name" ]; then
            if [ -d "$dir_name/.git" ]; then
                status="EXISTS (Git repo)"
            else
                status="EXISTS (Not a Git repo)"
            fi
        fi
        printf "  %-15s %s [%s]\n" "$dir_name" "$repo_url" "$status"
    done
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -l|--list)
        list_repos
        exit 0
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use -h or --help for usage information"
        exit 1
        ;;
esac
