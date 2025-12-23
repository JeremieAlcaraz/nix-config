# Nushell Environment Config File - Marigold (macOS) - Géré par Nix
# version = "0.95.0"

def create_left_prompt [] {
    let dir = match (do --ignore-errors { $env.PWD | path relative-to $nu.home-path }) {
        null => $env.PWD
        '' => '~'
        $relative_pwd => ([~ $relative_pwd] | path join)
    }

    let path_color = (if (is-admin) { ansi red_bold } else { ansi green_bold })
    let separator_color = (if (is-admin) { ansi light_red_bold } else { ansi light_green_bold })
    let path_segment = $"($path_color)($dir)"

    $path_segment | str replace --all (char path_sep) $"($separator_color)(char path_sep)($path_color)"
}

def create_right_prompt [] {
    # create a right prompt in magenta with green separators and am/pm underlined
    let time_segment = ([
        (ansi reset)
        (ansi magenta)
        (date now | format date '%x %X') # try to respect user's locale
    ] | str join | str replace --regex --all "([/:])" $"(ansi green)${1}(ansi magenta)" |
        str replace --regex --all "([AP]M)" $"(ansi magenta_underline)${1}")

    let last_exit_code = if ($env.LAST_EXIT_CODE != 0) {([
        (ansi rb)
        ($env.LAST_EXIT_CODE)
    ] | str join)
    } else { "" }

    ([$last_exit_code, (char space), $time_segment] | str join)
}

# Use nushell functions to define your right and left prompt
# NOTE: These are default prompts, overridden by Starship in config.nu
$env.PROMPT_COMMAND = {|| create_left_prompt }
$env.PROMPT_COMMAND_RIGHT = {|| create_right_prompt }

# The prompt indicators
$env.PROMPT_INDICATOR = {|| "> " }
$env.PROMPT_INDICATOR_VI_INSERT = {|| ": " }
$env.PROMPT_INDICATOR_VI_NORMAL = {|| "> " }
$env.PROMPT_MULTILINE_INDICATOR = {|| "::: " }

# Environment variable conversions
$env.ENV_CONVERSIONS = {
    "PATH": {
        from_string: { |s| $s | split row (char esep) | path expand --no-symlink }
        to_string: { |v| $v | path expand --no-symlink | str join (char esep) }
    }
    "Path": {
        from_string: { |s| $s | split row (char esep) | path expand --no-symlink }
        to_string: { |v| $v | path expand --no-symlink | str join (char esep) }
    }
}

# Directories to search for scripts when calling source or use
$env.NU_LIB_DIRS = [
    ($nu.default-config-dir | path join 'scripts')
    ($nu.data-dir | path join 'completions')
]

# Directories to search for plugin binaries
$env.NU_PLUGIN_DIRS = [
    ($nu.default-config-dir | path join 'plugins')
]

# PATH configuration - Nix managed
use std "path add"
# Home Manager adds Nix paths automatically via sessionPath
path add ($env.HOME | path join ".local" "bin")

# Shell identifier for Starship (MUST be set BEFORE starship init)
# Clear other shell version variables inherited from parent shell
hide-env --ignore-errors ZSH_VERSION
hide-env --ignore-errors FISH_VERSION
hide-env --ignore-errors BASH_VERSION
hide-env --ignore-errors STARSHIP_SHELL

# Force STARSHIP_SHELL to nu (override inherited value from parent shell)
$env.STARSHIP_SHELL = "nu"

# Starship - use XDG config location
$env.STARSHIP_CONFIG = ($env.HOME | path join ".config" "starship.toml")

# Initialize tools (cache in ~/.cache for performance)
# Only generate starship init once (not on every shell startup)
const cache_root = ($nu.home-path | path join ".cache")
const starship_cache_dir = ($cache_root | path join "starship")
const starship_cache = ($starship_cache_dir | path join "init.nu")
if (which starship | is-not-empty) {
    if not ($starship_cache | path exists) {
        if not ($cache_root | path exists) { mkdir $cache_root }
        if not ($starship_cache_dir | path exists) { mkdir $starship_cache_dir }
        with-env {STARSHIP_SHELL: "nu"} {
            starship init nu | save -f $starship_cache
        }
    }
}

# Zoxide init (if available)
if (which zoxide | is-not-empty) {
    const zoxide_cache = ($nu.home-path | path join ".zoxide.nu")
    if not ($zoxide_cache | path exists) {
        zoxide init nushell | save -f $zoxide_cache
    }
}

# Carapace completions (if available)
if (which carapace | is-not-empty) {
    $env.CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense'
    const carapace_cache = ($nu.home-path | path join ".cache" "carapace" "init.nu")
    if not ($carapace_cache | path exists) {
        mkdir ($nu.home-path | path join ".cache" "carapace")
        carapace _carapace nushell | save --force $carapace_cache
    }
}
