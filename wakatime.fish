###
# wakatime.fish - Enhanced Terminal Activity Tracking
#
# Comprehensive hook script to send detailed WakaTime heartbeats
# Enhanced version with comprehensive system information
# Original: https://github.com/ik11235/wakatime.fish
###

function __register_wakatime_fish_before_exec -e fish_postexec
  # Allow disabling via environment variable
  if set -q FISH_WAKATIME_DISABLED
    return 0
  end
  
  # Get the executed command
  set -l exec_command_str
  set exec_command_str (string split -f1 ' ' "$argv")

  # Skip exit commands and other non-trackable commands
  if test "$exec_command_str" = 'exit' -o "$exec_command_str" = 'clear' -o "$exec_command_str" = 'history'
    return 0
  end

  # Plugin identification
  set -l PLUGIN_NAME "ik11235/wakatime.fish-enhanced"
  set -l PLUGIN_VERSION "1.0.0"

  # Initialize variables
  set -l project
  set -l wakatime_path
  set -l branch
  set -l category
  set -l language
  set -l wakatime_hostname
  set -l project_folder
  set -l alternate_project

  # Find WakaTime CLI
  if type -p wakatime 2>&1 > /dev/null
    set wakatime_path (type -p wakatime)
  else if type -p ~/.wakatime/wakatime-cli 2>&1 > /dev/null
    set wakatime_path (type -p ~/.wakatime/wakatime-cli)
  else
    echo "wakatime command not found. Please install from https://wakatime.com/terminal"
    return 1
  end

  # Get comprehensive hostname information
  if type -p hostnamectl 2>&1 > /dev/null
    set wakatime_hostname (hostnamectl --static 2>/dev/null || hostname)
  else
    set wakatime_hostname (hostname)
  end

  # Enhanced project detection with Git information
  if git rev-parse --is-inside-work-tree &> /dev/null
    # Get project name from Git root
    set project (basename (git rev-parse --show-toplevel))
    set project_folder (git rev-parse --show-toplevel)
    
    # Get current branch
    set branch (git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null)
    
    # Set alternate project as directory name if different from Git root
    set -l current_dir (basename (pwd))
    if test "$current_dir" != "$project"
      set alternate_project "$current_dir"
    end
  else
    # Fallback project detection based on common project indicators
    set -l current_path (pwd)
    
    # Check for common project files
    if test -f "package.json" -o -f "Cargo.toml" -o -f "pyproject.toml" -o -f "composer.json" -o -f "pom.xml" -o -f "build.gradle"
      set project (basename $current_path)
      set project_folder $current_path
    else if test -f "../package.json" -o -f "../Cargo.toml" -o -f "../pyproject.toml"
      set project (basename (dirname $current_path))
      set project_folder (dirname $current_path)
      set alternate_project (basename $current_path)
    else
      # Default to "Terminal" for general shell usage
      set project "Terminal"
    end
  end

  # Enhanced category detection based on command patterns
  switch "$exec_command_str"
    case "git" "gh" "hub"
      set category "code reviewing"
    case "npm" "yarn" "pnpm" "cargo" "pip" "composer" "mvn" "gradle"
      set category "building"
    case "docker" "docker-compose" "podman"
      set category "building"
    case "pytest" "jest" "vitest" "phpunit" "cargo-test" "go-test"
      set category "running tests"
    case "vim" "nvim" "emacs" "nano" "code" "subl" "atom"
      set category "coding"
    case "ssh" "curl" "wget" "httpie"
      set category "communicating"
    case "man" "help" "info" "--help"
      set category "learning"
    case "ls" "find" "grep" "rg" "fd" "locate"
      set category "browsing"
    case "make" "cmake" "ninja"
      set category "building"
    case "gdb" "lldb" "strace" "ltrace"
      set category "debugging"
    case "*"
      set category "coding"  # Default category
  end

  # Enhanced language detection based on context
  if test -n "$project_folder" -a "$project_folder" != ""
    # Try to detect language from project files in the current directory or project root
    if test -f "package.json" -o -f "yarn.lock" -o -f "pnpm-lock.yaml"
      set language "JavaScript"
    else if test -f "Cargo.toml" -o -f "Cargo.lock"
      set language "Rust"
    else if test -f "pyproject.toml" -o -f "setup.py" -o -f "requirements.txt"
      set language "Python"
    else if test -f "composer.json" -o -f "composer.lock"
      set language "PHP"
    else if test -f "pom.xml" -o -f "build.gradle" -o -f "build.gradle.kts"
      set language "Java"
    else if test -f "go.mod" -o -f "go.sum"
      set language "Go"
    else if test -f "Gemfile" -o -f "Gemfile.lock"
      set language "Ruby"
    else if test -f "mix.exs"
      set language "Elixir"
    else if test -f "deno.json" -o -f "deno.jsonc"
      set language "TypeScript"
    else if test -f "*.ts" -o -f "tsconfig.json"
      set language "TypeScript"
    end
  end

  # Build comprehensive WakaTime command with all available parameters
  set -l wakatime_args \
    --write \
    --plugin "$PLUGIN_NAME/$PLUGIN_VERSION" \
    --hostname "$wakatime_hostname" \
    --entity-type "app" \
    --project "$project" \
    --entity "$exec_command_str" \
    --category "$category"

  # Add optional parameters if available
  if test -n "$branch" -a "$branch" != ""
    set wakatime_args $wakatime_args --alternate-branch "$branch"
  end

  if test -n "$language" -a "$language" != ""
    set wakatime_args $wakatime_args --alternate-language "$language"
  end

  if test -n "$project_folder" -a "$project_folder" != ""
    set wakatime_args $wakatime_args --project-folder "$project_folder"
  end

  if test -n "$alternate_project" -a "$alternate_project" != ""
    set wakatime_args $wakatime_args --alternate-project "$alternate_project"
  end

  # Add system information as additional context (if supported by your WakaTime instance)
  # Note: These may not be standard WakaTime fields but could be useful for custom implementations
  set wakatime_args $wakatime_args --timeout 30

  # Execute WakaTime CLI in background with proper job control
  fish -c "eval \"$wakatime_path $wakatime_args\" &> /dev/null" &
end

# Optional: Add a function to manually trigger WakaTime heartbeat with custom parameters
function wakatime_heartbeat -d "Send a manual WakaTime heartbeat"
  set -l entity $argv[1]
  set -l category $argv[2]
  
  if test -z "$entity"
    echo "Usage: wakatime_heartbeat <entity> [category]"
    return 1
  end
  
  if test -z "$category"
    set category "coding"
  end
  
  set -l project "Terminal"
  if git rev-parse --is-inside-work-tree &> /dev/null
    set project (basename (git rev-parse --show-toplevel))
  end
  
  if type -p wakatime 2>&1 > /dev/null
    wakatime --write --entity-type app --project "$project" --entity "$entity" --category "$category"
  else if type -p ~/.wakatime/wakatime-cli 2>&1 > /dev/null
    ~/.wakatime/wakatime-cli --write --entity-type app --project "$project" --entity "$entity" --category "$category"
  end
end
