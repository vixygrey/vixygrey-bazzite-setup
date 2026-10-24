#!/usr/bin/env bash
# Install the Dracula Sakura desktop and terminal setup for Bazzite.
set -Eeuo pipefail
IFS=$'\n\t'

readonly FLATHUB_REPOSITORY='https://dl.flathub.org/repo/flathub.flatpakrepo'
readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly SHELL_CONFIG_DIR="$CONFIG_HOME/dracula-sakura"
readonly -a CLI_PACKAGES=(
  bat
  eza
  btop
  trippy
  micro
  leaf-markdown-viewer
  starship
  fastfetch
  duf
  fzf
)

DRY_RUN=0

log() {
  printf '==> %s\n' "$*"
}

warn() {
  printf 'WARNING: %s\n' "$*" >&2
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

run() {
  if (( DRY_RUN )); then
    printf '+ '
    printf '%q ' "$@"
    printf '\n'
    return
  fi

  "$@"
}

try_run() {
  if ! run "$@"; then
    warn "Command failed: $*"
  fi
}

write_file() {
  local target=$1
  local temporary

  if (( DRY_RUN )); then
    log "Would write $target"
    cat >/dev/null
    return
  fi

  mkdir -p "$(dirname "$target")"
  temporary=$(mktemp "${target}.XXXXXX")
  cat >"$temporary"
  chmod 0644 "$temporary"
  mv "$temporary" "$target"
}

set_config_line() {
  local target=$1
  local key=$2
  local value=$3
  local temporary

  if (( DRY_RUN )); then
    log "Would set $key in $target"
    return
  fi

  mkdir -p "$(dirname "$target")"
  touch "$target"
  temporary=$(mktemp "${target}.XXXXXX")
  awk -v key="$key" -v value="$value" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      if (!written) {
        print value
        written = 1
      }
      next
    }
    { print }
    END {
      if (!written) print value
    }
  ' "$target" >"$temporary"
  chmod 0644 "$temporary"
  mv "$temporary" "$target"
}

ensure_source_block() {
  local target=$1
  local source_file=$2
  local marker='# Dracula Sakura shell setup'

  if (( DRY_RUN )); then
    log "Would source $source_file from $target"
    return
  fi

  touch "$target"
  if ! grep -Fqx "$marker" "$target"; then
    cat >>"$target" <<EOF

$marker
[ -r "$source_file" ] && source "$source_file"
EOF
  fi
}

require_bazzite() {
  [[ -r /etc/os-release ]] || die 'The /etc/os-release file is required.'

  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID:-}" != *bazzite* && "${VARIANT_ID:-}" != *bazzite* && "${IMAGE_ID:-}" != *bazzite* ]]; then
    die 'This setup only supports a Bazzite image.'
  fi
}

ensure_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi

  if (( DRY_RUN )); then
    log 'Would install Homebrew with the official installer'
    return
  fi

  log 'Installing Homebrew'
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    # shellcheck disable=SC1091
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  elif [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
    # shellcheck disable=SC1091
    eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
  fi

  command -v brew >/dev/null 2>&1 || die 'Homebrew installation did not provide brew on PATH.'
}

install_kitty() {
  local installer desktop line
  log 'Installing Kitty from the official binary distribution'
  if (( DRY_RUN )); then
    log 'Would download and run https://sw.kovidgoyal.net/kitty/installer.sh with launch=n'
  else
    installer=$(mktemp)
    if ! curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh -o "$installer"; then
      rm -f "$installer"
      die 'Could not download the Kitty installer.'
    fi
    if ! sh "$installer" launch=n; then
      rm -f "$installer"
      die 'Kitty installation failed.'
    fi
    rm -f "$installer"
  fi

  run mkdir -p "$HOME/.local/bin" "$DATA_HOME/applications"
  run ln -sfn "$HOME/.local/kitty.app/bin/kitty" "$HOME/.local/bin/kitty"
  run ln -sfn "$HOME/.local/kitty.app/bin/kitten" "$HOME/.local/bin/kitten"
  for desktop in kitty.desktop kitty-open.desktop; do
    if (( DRY_RUN )); then
      log "Would install $DATA_HOME/applications/$desktop with absolute executable and icon paths"
    else
      while IFS= read -r line || [[ -n "$line" ]]; do
        line=${line/#Exec=kitty/Exec=\"$HOME\/.local\/kitty.app\/bin\/kitty\"}
        line=${line/#Icon=kitty/Icon=$HOME\/.local\/kitty.app\/share\/icons\/hicolor\/256x256\/apps\/kitty.png}
        printf '%s\n' "$line"
      done <"$HOME/.local/kitty.app/share/applications/$desktop" |
        write_file "$DATA_HOME/applications/$desktop"
    fi
  done
  write_file "$CONFIG_HOME/xdg-terminals.list" <<'EOF'
kitty.desktop
EOF
}

install_packages() {
  command -v flatpak >/dev/null 2>&1 || die 'Flatpak is required to install desktop applications.'

  log 'Installing Discord, Bitwarden, and Google Chrome from Flathub'
  run flatpak remote-add --if-not-exists --user flathub "$FLATHUB_REPOSITORY"
  run flatpak install --user --noninteractive flathub \
    com.discordapp.Discord com.bitwarden.desktop com.google.Chrome
  install_kitty

  ensure_homebrew
  log 'Installing terminal tools from Homebrew'
  run brew install "${CLI_PACKAGES[@]}"
  run brew install --cask font-jetbrains-mono-nerd-font

  if command -v fc-cache >/dev/null 2>&1; then
    run fc-cache -f
  fi
}

write_kitty_config() {
  write_file "$CONFIG_HOME/kitty/kitty.conf" <<'EOF'
# Dracula Sakura
font_family      JetBrainsMono Nerd Font
font_size        12.0
adjust_line_height 2

foreground       #f8f8f2
background       #282a36
selection_foreground #f8f8f2
selection_background #44475a
cursor           #ff79c6
cursor_text_color #282a36
url_color        #8be9fd

color0           #21222c
color1           #ff5555
color2           #50fa7b
color3           #f1fa8c
color4           #bd93f9
color5           #ff79c6
color6           #8be9fd
color7           #f8f8f2
color8           #6272a4
color9           #ff6e6e
color10          #69ff94
color11          #ffffa5
color12          #d6acff
color13          #ff92df
color14          #a4ffff
color15          #ffffff

active_border_color   #ff79c6
inactive_border_color #44475a
active_tab_background #bd93f9
active_tab_foreground #282a36
inactive_tab_background #44475a
inactive_tab_foreground #f8f8f2
tab_bar_background    #282a36

background_opacity 0.96
window_padding_width 10
placement_strategy center
scrollback_lines 10000
enable_audio_bell no
confirm_os_window_close 0
shell_integration enabled
EOF
}

write_bat_config() {
  write_file "$CONFIG_HOME/bat/config" <<'EOF'
--theme="Dracula-Sakura"
--style="numbers,changes,header"
--italic-text=always
--paging=auto
EOF

  write_file "$CONFIG_HOME/bat/themes/Dracula-Sakura.tmTheme" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>name</key><string>Dracula-Sakura</string>
  <key>settings</key>
  <array>
    <dict>
      <key>settings</key>
      <dict>
        <key>background</key><string>#282A36</string>
        <key>foreground</key><string>#F8F8F2</string>
        <key>caret</key><string>#FF79C6</string>
        <key>invisibles</key><string>#6272A4</string>
        <key>lineHighlight</key><string>#343746</string>
        <key>selection</key><string>#44475A</string>
        <key>selectionForeground</key><string>#F8F8F2</string>
      </dict>
    </dict>
    <dict><key>scope</key><string>comment</string><key>settings</key><dict><key>foreground</key><string>#6272A4</string><key>fontStyle</key><string>italic</string></dict></dict>
    <dict><key>scope</key><string>string</string><key>settings</key><dict><key>foreground</key><string>#F1FA8C</string></dict></dict>
    <dict><key>scope</key><string>constant.numeric, constant.language</string><key>settings</key><dict><key>foreground</key><string>#BD93F9</string></dict></dict>
    <dict><key>scope</key><string>keyword, storage</string><key>settings</key><dict><key>foreground</key><string>#FF79C6</string></dict></dict>
    <dict><key>scope</key><string>entity.name.function, support.function</string><key>settings</key><dict><key>foreground</key><string>#50FA7B</string></dict></dict>
    <dict><key>scope</key><string>entity.name.type, support.type, storage.type</string><key>settings</key><dict><key>foreground</key><string>#8BE9FD</string></dict></dict>
    <dict><key>scope</key><string>variable, variable.parameter</string><key>settings</key><dict><key>foreground</key><string>#F8F8F2</string></dict></dict>
    <dict><key>scope</key><string>invalid</string><key>settings</key><dict><key>foreground</key><string>#FF5555</string></dict></dict>
    <dict><key>scope</key><string>markup.heading</string><key>settings</key><dict><key>foreground</key><string>#FF92DF</string><key>fontStyle</key><string>bold</string></dict></dict>
  </array>
</dict>
</plist>
EOF

  run bat cache --build
}

write_btop_config() {
  write_file "$CONFIG_HOME/btop/themes/dracula-sakura.theme" <<'EOF'
# Dracula Sakura
[main_bg]="#282a36"
[main_fg]="#f8f8f2"
[title]="#ff79c6"
[hi_fg]="#ff92df"
[selected_bg]="#44475a"
[selected_fg]="#ffffff"
[inactive_fg]="#6272a4"
[graph_text]="#8be9fd"
[meter_bg]="#44475a"
[proc_misc]="#bd93f9"
[cpu_box]="#ff79c6"
[mem_box]="#bd93f9"
[net_box]="#8be9fd"
[proc_box]="#50fa7b"
[div_line]="#44475a"
[temp_start]="#50fa7b"
[temp_mid]="#f1fa8c"
[temp_end]="#ff5555"
[cpu_start]="#50fa7b"
[cpu_mid]="#f1fa8c"
[cpu_end]="#ff5555"
[free_start]="#8be9fd"
[free_mid]="#bd93f9"
[free_end]="#ff79c6"
[cached_start]="#8be9fd"
[cached_mid]="#bd93f9"
[cached_end]="#ff79c6"
[available_start]="#50fa7b"
[available_mid]="#8be9fd"
[available_end]="#bd93f9"
[used_start]="#50fa7b"
[used_mid]="#f1fa8c"
[used_end]="#ff5555"
[download_start]="#bd93f9"
[download_mid]="#8be9fd"
[download_end]="#50fa7b"
[upload_start]="#ff79c6"
[upload_mid]="#bd93f9"
[upload_end]="#8be9fd"
[process_start]="#50fa7b"
[process_mid]="#f1fa8c"
[process_end]="#ff5555"
[proc_pause_bg]="#ff5555"
[proc_follow_bg]="#bd93f9"
[proc_banner_bg]="#ff79c6"
[proc_banner_fg]="#282a36"
[followed_bg]="#bd93f9"
[followed_fg]="#282a36"
EOF

  set_config_line "$CONFIG_HOME/btop/btop.conf" 'color_theme' 'color_theme = "dracula-sakura"'
}

write_micro_config() {
  write_file "$CONFIG_HOME/micro/colorschemes/dracula-sakura.micro" <<'EOF'
color-link default "#f8f8f2,#282a36"
color-link comment "#6272a4,#282a36"
color-link identifier "#f8f8f2,#282a36"
color-link constant "#bd93f9,#282a36"
color-link constant.string "#f1fa8c,#282a36"
color-link constant.string.char "#f1fa8c,#282a36"
color-link statement "#ff79c6,#282a36"
color-link symbol.operator "#ff79c6,#282a36"
color-link preproc "#ffb86c,#282a36"
color-link type "#8be9fd,#282a36"
color-link special "#50fa7b,#282a36"
color-link underlined "#8be9fd,#282a36"
color-link error "bold #ff5555,#282a36"
color-link todo "bold #ff92df,#282a36"
color-link hlsearch "#282a36,#f1fa8c"
color-link statusline "#282a36,#ff79c6"
color-link tabbar "#f8f8f2,#44475a"
color-link indent-char "#44475a,#282a36"
color-link line-number "#6272a4,#282a36"
color-link current-line-number "#ff79c6,#282a36"
color-link diff-added "#50fa7b,#282a36"
color-link diff-modified "#f1fa8c,#282a36"
color-link diff-deleted "#ff5555,#282a36"
color-link gutter-error "#ff5555,#282a36"
color-link gutter-warning "#f1fa8c,#282a36"
color-link cursor-line "#343746,#282a36"
color-link color-column "#343746,#282a36"
color-link symbol.tag "#bd93f9,#282a36"
color-link match-brace "#282a36,#bd93f9"
color-link tab-error "#ff5555,#282a36"
color-link trailingws "#ff5555,#282a36"
EOF
  write_file "$CONFIG_HOME/micro/settings.json" <<'EOF'
{
  "colorscheme": "dracula-sakura",
  "cursorline": true,
  "diffgutter": true,
  "softwrap": true,
  "tabsize": 4,
  "tabstospaces": true,
  "truecolor": "auto"
}
EOF
}

write_leaf_config() {
  write_file "$CONFIG_HOME/leaf/config.toml" <<'EOF'
theme = "dracula-sakura.toml"
editor = "micro"
width = 100
watch = false
file-history-length = 20
EOF

  write_file "$CONFIG_HOME/leaf/dracula-sakura.toml" <<'EOF'
base = "ocean"
syntax = "base16-ocean.dark"

[ui]
toc_bg = "#21222c"
toc_border = "#44475a"
content_bg = "#282a36"
scrollbar_hover = "#ff79c6"
status_bg = "#21222c"
status_separator = "#6272a4"
status_brand_fg = "#282a36"
status_brand_bg = "#ff79c6"
status_filename_fg = "#f8f8f2"
status_filename_bg = "#44475a"
status_watch_fg = "#50fa7b"
status_watch_bg = "#343746"
status_reloaded_fg = "#282a36"
status_reloaded_bg = "#50fa7b"
status_search_fg = "#f1fa8c"
status_search_bg = "#44475a"
status_success_fg = "#50fa7b"
status_success_bg = "#343746"
status_warning_fg = "#f1fa8c"
status_error_fg = "#ff5555"
status_error_bg = "#442b3a"
status_shortcut_fg = "#6272a4"
status_percent_fg = "#ff79c6"
toc_hover_fg = "#ffffff"
toc_header_fg = "#bd93f9"
toc_active_bg = "#44475a"
toc_inactive_bg = "#21222c"
toc_accent = "#ff79c6"
toc_index_inactive = "#6272a4"
toc_primary_active = "#ffffff"
toc_primary_inactive = "#f8f8f2"
toc_secondary_inactive = "#6272a4"
toc_secondary_text_active = "#f8f8f2"
toc_secondary_text_inactive = "#bd93f9"

[markdown]
search_highlight_bg = "#44475a"
search_match_bg = "#f1fa8c"
code_gutter = "#44475a"
blockquote_marker = "#bd93f9"
list_level_1 = "#ff79c6"
list_level_2 = "#bd93f9"
list_level_3 = "#8be9fd"
ordered_list = "#f1fa8c"
table_border = "#6272a4"
table_separator = "#44475a"
table_header = "#ff92df"
table_cell = "#f8f8f2"
heading_1 = "#ff79c6"
heading_2 = "#bd93f9"
heading_3 = "#8be9fd"
heading_4 = "#50fa7b"
heading_other = "#ffb86c"
heading_underline = "#44475a"
code_frame = "#6272a4"
code_label = "#bd93f9"
inline_code_fg = "#8be9fd"
inline_code_bg = "#343746"
rule = "#44475a"
link_icon = "#8be9fd"
link_text = "#8be9fd"
link_hover = "#a4ffff"
blockquote_text = "#f8f8f2"
text = "#f8f8f2"
strong_text = "#ffffff"
latex_inline_fg = "#bd93f9"
latex_inline_bg = "#343746"
latex_block_fg = "#bd93f9"
mermaid_keyword = "#ff79c6"
mermaid_arrow = "#8be9fd"
mermaid_label = "#50fa7b"
mermaid_block_fg = "#f8f8f2"
mark_fg = "#282a36"
mark_bg = "#f1fa8c"
task_checked = "#50fa7b"
task_unchecked = "#6272a4"
alert_note = "#8be9fd"
alert_tip = "#50fa7b"
alert_important = "#bd93f9"
alert_warning = "#f1fa8c"
alert_caution = "#ff5555"
footnote_ref = "#8be9fd"
footnote_text = "#f8f8f2"
EOF
}

write_trippy_config() {
  write_file "$CONFIG_HOME/trippy/trippy.toml" <<'EOF'
[tui]
tui-preserve-screen = false
tui-refresh-rate = "200ms"

[theme-colors]
bg-color = "282a36"
border-color = "bd93f9"
text-color = "f8f8f2"
tab-text-color = "ff79c6"
hops-table-header-bg-color = "44475a"
hops-table-header-text-color = "f8f8f2"
hops-table-row-active-text-color = "f8f8f2"
hops-table-row-inactive-text-color = "6272a4"
hops-table-row-active-selected-bg-color = "bd93f9"
hops-table-row-active-selected-text-color = "282a36"
hops-table-row-inactive-selected-bg-color = "44475a"
hops-table-row-inactive-selected-text-color = "f8f8f2"
hops-chart-selected-color = "ff79c6"
hops-chart-unselected-color = "6272a4"
hops-chart-axis-color = "44475a"
frequency-chart-bar-color = "50fa7b"
frequency-chart-text-color = "f8f8f2"
flows-chart-bar-selected-color = "ff79c6"
flows-chart-bar-unselected-color = "6272a4"
flows-chart-text-current-color = "f8f8f2"
flows-chart-text-non-current-color = "bd93f9"
samples-chart-color = "f1fa8c"
samples-chart-lost-color = "ff5555"
help-dialog-bg-color = "343746"
help-dialog-text-color = "f8f8f2"
settings-dialog-bg-color = "343746"
settings-tab-text-color = "ff79c6"
settings-table-header-text-color = "282a36"
settings-table-header-bg-color = "bd93f9"
settings-table-row-text-color = "f8f8f2"
map-world-color = "bd93f9"
map-radius-color = "f1fa8c"
map-selected-color = "ff79c6"
map-info-panel-border-color = "bd93f9"
map-info-panel-bg-color = "282a36"
map-info-panel-text-color = "f8f8f2"
info-bar-bg-color = "44475a"
info-bar-text-color = "f8f8f2"
EOF
}

write_starship_config() {
  write_file "$CONFIG_HOME/starship.toml" <<'EOF'
"$schema" = "https://starship.rs/config-schema.json"
add_newline = false
palette = "dracula_sakura"
format = "$directory$git_branch$git_status$fill$cmd_duration$line_break$character"

[fill]
symbol = " "

[character]
success_symbol = "[❯](pink)"
error_symbol = "[❯](red)"
vimcmd_symbol = "[❮](purple)"

[directory]
style = "bold lavender"
truncation_length = 3
truncate_to_repo = true

[git_branch]
symbol = ""
style = "bold cyan"
format = " [$symbol$branch]($style)"

[git_status]
style = "bold yellow"
format = "([$all_status$ahead_behind]($style))"

[cmd_duration]
min_time = 1_000
format = " [󰔛 $duration](orange)"

[package]
disabled = true

[palettes.dracula_sakura]
background = "#282a36"
foreground = "#f8f8f2"
comment = "#6272a4"
cyan = "#8be9fd"
green = "#50fa7b"
orange = "#ffb86c"
pink = "#ff79c6"
purple = "#bd93f9"
lavender = "#d6acff"
red = "#ff5555"
yellow = "#f1fa8c"
EOF
}

write_fastfetch_config() {
  write_file "$CONFIG_HOME/fastfetch/config.jsonc" <<'EOF'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "small",
    "color": {
      "1": "#ff79c6",
      "2": "#bd93f9",
      "3": "#8be9fd"
    },
    "padding": {
      "top": 1,
      "left": 2
    }
  },
  "display": {
    "separator": "  "
  },
  "modules": [
    "title",
    "separator",
    { "type": "os", "keyColor": "#ff79c6" },
    { "type": "kernel", "keyColor": "#bd93f9" },
    { "type": "uptime", "keyColor": "#8be9fd" },
    { "type": "packages", "keyColor": "#50fa7b" },
    { "type": "shell", "keyColor": "#f1fa8c" },
    { "type": "terminal", "keyColor": "#ffb86c" },
    { "type": "cpu", "keyColor": "#ff79c6" },
    { "type": "gpu", "keyColor": "#bd93f9" },
    { "type": "memory", "keyColor": "#8be9fd" },
    { "type": "disk", "keyColor": "#50fa7b" },
    { "type": "break" },
    { "type": "colors", "symbol": "circle" }
  ]
}
EOF
}

write_shell_config() {
  write_file "$SHELL_CONFIG_DIR/shell.common" <<'EOF'
# Dracula Sakura terminal defaults
export BAT_THEME='Dracula-Sakura'
export BAT_STYLE='numbers,changes,header'
export EDITOR='micro'
export VISUAL='micro'
export EZA_COLORS='da=38;2;189;147;249:di=38;2;139;233;253:ex=38;2;80;250;123:fi=38;2;248;248;242:ln=38;2;255;121;198:uu=38;2;80;250;123:gu=38;2;80;250;123:sn=38;2;255;184;108:ur=38;2;255;85;85:uw=38;2;255;85;85:ux=38;2;255;85;85:ue=38;2;255;85;85:gr=38;2;255;184;108:gw=38;2;255;184;108:gx=38;2;255;184;108:tr=38;2;255;85;85:tw=38;2;255;85;85:tx=38;2;255;85;85'
export FZF_DEFAULT_OPTS='--height 45% --layout=reverse --border=rounded --info=inline --prompt="❯ " --pointer="▶" --marker="✓" --color=bg:#282a36,bg+:#44475a,fg:#f8f8f2,fg+:#ffffff,hl:#ff79c6,hl+:#ff92df,info:#8be9fd,prompt:#bd93f9,pointer:#ff79c6,marker:#50fa7b,spinner:#bd93f9,header:#6272a4,border:#bd93f9,label:#ff79c6,query:#f8f8f2'

alias cat='bat --paging=never'
alias ls='eza --group-directories-first --icons=auto'
alias ll='eza --long --group-directories-first --icons=auto --git'
alias la='eza --all --long --group-directories-first --icons=auto --git'
alias tree='eza --tree --level=2 --group-directories-first --icons=auto'
alias top='btop'
alias htop='btop'
alias trippy='trip'
alias traceroute='trip'
alias vi='micro'
alias vim='micro'
alias md='leaf'
alias ff='fastfetch'
alias df='duf'
alias du='duf'
alias f='fzf'
EOF

  write_file "$SHELL_CONFIG_DIR/shell.bash" <<'EOF'
# shellcheck shell=bash
source "${XDG_CONFIG_HOME:-$HOME/.config}/dracula-sakura/shell.common"

if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --bash)"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi
EOF

  write_file "$SHELL_CONFIG_DIR/shell.zsh" <<'EOF'
source "${XDG_CONFIG_HOME:-$HOME/.config}/dracula-sakura/shell.common"

if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
EOF

  write_file "$CONFIG_HOME/fish/conf.d/dracula-sakura.fish" <<'EOF'
# Dracula Sakura terminal defaults
set -gx BAT_THEME Dracula-Sakura
set -gx BAT_STYLE numbers,changes,header
set -gx EDITOR micro
set -gx VISUAL micro
set -gx EZA_COLORS 'da=38;2;189;147;249:di=38;2;139;233;253:ex=38;2;80;250;123:fi=38;2;248;248;242:ln=38;2;255;121;198'
set -gx FZF_DEFAULT_OPTS '--height 45% --layout=reverse --border=rounded --info=inline --prompt="❯ " --pointer="▶" --marker="✓" --color=bg:#282a36,bg+:#44475a,fg:#f8f8f2,fg+:#ffffff,hl:#ff79c6,hl+:#ff92df,info:#8be9fd,prompt:#bd93f9,pointer:#ff79c6,marker:#50fa7b,spinner:#bd93f9,header:#6272a4,border:#bd93f9,label:#ff79c6,query:#f8f8f2'

alias cat 'bat --paging=never'
alias ls 'eza --group-directories-first --icons=auto'
alias ll 'eza --long --group-directories-first --icons=auto --git'
alias la 'eza --all --long --group-directories-first --icons=auto --git'
alias tree 'eza --tree --level=2 --group-directories-first --icons=auto'
alias top btop
alias htop btop
alias trippy trip
alias traceroute trip
alias vi micro
alias vim micro
alias md leaf
alias ff fastfetch
alias df duf
alias du duf
alias f fzf

if type -q fzf
  fzf --fish | source
end

if type -q starship
  starship init fish | source
end
EOF

  case "$(basename "${SHELL:-/bin/bash}")" in
    bash)
      ensure_source_block "$HOME/.bashrc" "$SHELL_CONFIG_DIR/shell.bash"
      ;;
    zsh)
      ensure_source_block "$HOME/.zshrc" "$SHELL_CONFIG_DIR/shell.zsh"
      ;;
    fish)
      log 'Fish loads the Dracula Sakura configuration from conf.d.'
      ;;
    *)
      warn "The $(basename "${SHELL:-unknown}") shell needs manual setup."
      ;;
  esac
}

write_desktop_theme() {
  write_file "$SHELL_CONFIG_DIR/gtk.css" <<'EOF'
@define-color accent_color #ff79c6;
@define-color accent_bg_color #bd93f9;
@define-color accent_fg_color #282a36;
@define-color window_bg_color #282a36;
@define-color window_fg_color #f8f8f2;
@define-color view_bg_color #282a36;
@define-color view_fg_color #f8f8f2;
@define-color headerbar_bg_color #44475a;
@define-color headerbar_fg_color #f8f8f2;
@define-color card_bg_color #343746;
@define-color card_fg_color #f8f8f2;
@define-color popover_bg_color #343746;
@define-color popover_fg_color #f8f8f2;
EOF

  write_file "$CONFIG_HOME/gtk-3.0/gtk.css" <<EOF
@import url("$SHELL_CONFIG_DIR/gtk.css");
EOF
  write_file "$CONFIG_HOME/gtk-4.0/gtk.css" <<EOF
@import url("$SHELL_CONFIG_DIR/gtk.css");
EOF

  write_file "$DATA_HOME/color-schemes/Dracula-Sakura.colors" <<'EOF'
[ColorEffects:Disabled]
Color=98,114,164
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=0

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color=98,114,164
ColorAmount=0.025
ColorEffect=2
ContrastAmount=0.1
ContrastEffect=1
IntensityAmount=0
IntensityEffect=0

[Colors:Button]
BackgroundAlternate=52,55,70
BackgroundNormal=68,71,90
DecorationFocus=255,121,198
DecorationHover=189,147,249
ForegroundActive=255,255,255
ForegroundInactive=98,114,164
ForegroundLink=139,233,253
ForegroundNegative=255,85,85
ForegroundNeutral=255,184,108
ForegroundNormal=248,248,242
ForegroundPositive=80,250,123
ForegroundVisited=189,147,249

[Colors:Complementary]
BackgroundAlternate=33,34,44
BackgroundNormal=40,42,54
DecorationFocus=255,121,198
DecorationHover=189,147,249
ForegroundActive=255,255,255
ForegroundInactive=98,114,164
ForegroundLink=139,233,253
ForegroundNegative=255,85,85
ForegroundNeutral=255,184,108
ForegroundNormal=248,248,242
ForegroundPositive=80,250,123
ForegroundVisited=189,147,249

[Colors:Selection]
BackgroundAlternate=189,147,249
BackgroundNormal=189,147,249
DecorationFocus=255,121,198
DecorationHover=255,146,223
ForegroundActive=40,42,54
ForegroundInactive=68,71,90
ForegroundLink=40,42,54
ForegroundNegative=255,85,85
ForegroundNeutral=40,42,54
ForegroundNormal=40,42,54
ForegroundPositive=40,42,54
ForegroundVisited=40,42,54

[Colors:Tooltip]
BackgroundAlternate=52,55,70
BackgroundNormal=33,34,44
DecorationFocus=255,121,198
DecorationHover=189,147,249
ForegroundActive=255,255,255
ForegroundInactive=98,114,164
ForegroundLink=139,233,253
ForegroundNegative=255,85,85
ForegroundNeutral=255,184,108
ForegroundNormal=248,248,242
ForegroundPositive=80,250,123
ForegroundVisited=189,147,249

[Colors:View]
BackgroundAlternate=52,55,70
BackgroundNormal=40,42,54
DecorationFocus=255,121,198
DecorationHover=189,147,249
ForegroundActive=255,255,255
ForegroundInactive=98,114,164
ForegroundLink=139,233,253
ForegroundNegative=255,85,85
ForegroundNeutral=255,184,108
ForegroundNormal=248,248,242
ForegroundPositive=80,250,123
ForegroundVisited=189,147,249

[Colors:Window]
BackgroundAlternate=52,55,70
BackgroundNormal=40,42,54
DecorationFocus=255,121,198
DecorationHover=189,147,249
ForegroundActive=255,255,255
ForegroundInactive=98,114,164
ForegroundLink=139,233,253
ForegroundNegative=255,85,85
ForegroundNeutral=255,184,108
ForegroundNormal=248,248,242
ForegroundPositive=80,250,123
ForegroundVisited=189,147,249

[General]
ColorScheme=Dracula-Sakura
Name=Dracula-Sakura
shadeSortColumn=true

[KDE]
contrast=4

[WM]
activeBackground=68,71,90
activeBlend=255,121,198
activeForeground=248,248,242
inactiveBackground=40,42,54
inactiveBlend=98,114,164
inactiveForeground=98,114,164
EOF

  if command -v gsettings >/dev/null 2>&1 && gsettings list-schemas | grep -Fxq 'org.gnome.desktop.interface'; then
    try_run gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    try_run gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark
    try_run gsettings set org.gnome.desktop.interface accent-color pink
  fi

  if [[ "${XDG_CURRENT_DESKTOP:-}" == *KDE* ]]; then
    if command -v plasma-apply-colorscheme >/dev/null 2>&1; then
      run plasma-apply-colorscheme Dracula-Sakura
    fi
    if command -v lookandfeeltool >/dev/null 2>&1; then
      try_run lookandfeeltool -a org.kde.breezedark.desktop
    fi
    if command -v kwriteconfig6 >/dev/null 2>&1; then
      run kwriteconfig6 --file kdeglobals --group General --key TerminalApplication "$HOME/.local/kitty.app/bin/kitty"
      run kwriteconfig6 --file kdeglobals --group General --key TerminalService kitty.desktop
    fi
  fi

  if command -v xdg-mime >/dev/null 2>&1; then
    try_run xdg-mime default kitty.desktop x-scheme-handler/terminal
  fi
}

usage() {
  cat <<'EOF'
Usage: setup-dracula-sakura.sh [--dry-run]
EOF
}

main() {
  case "${1:-}" in
    '')
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    --help|-h)
      usage
      return
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac

  require_bazzite
  install_packages
  write_kitty_config
  write_bat_config
  write_btop_config
  write_micro_config
  write_leaf_config
  write_trippy_config
  write_starship_config
  write_fastfetch_config
  write_shell_config
  write_desktop_theme

  log 'Dracula Sakura setup is complete. Start a new shell session to load the aliases and prompt.'
}

main "$@"
