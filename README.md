# Vixygrey Bazzite Setup

Install a Dracula Sakura desktop and terminal setup on Bazzite.

The script installs Kitty through Flathub. It installs terminal tools through Homebrew. It configures the supported desktop and terminal applications.

## Included components

- Kitty with a Dracula Sakura color palette.
- bat, eza, btop, Trippy, Micro, Leaf, Starship, Fastfetch, duf, and fzf.
- JetBrains Mono Nerd Font.
- Bash, Zsh, and Fish aliases with Starship and fzf integration.
- GTK dark colors, GNOME dark mode, and a KDE color scheme.

## Use

CAUTION: Copy existing application configuration files before you run the script. The script replaces selected configuration files under `~/.config`.

1. Clone this repository.
2. Review `setup-dracula-sakura.sh`.
3. Run the setup script on Bazzite.

```bash
./setup-dracula-sakura.sh
```

Run this command to display the planned commands without system changes:

```bash
./setup-dracula-sakura.sh --dry-run
```

Start a new shell session after the script completes. Log out and log in to apply all desktop changes.

## Package sources

Kitty installs from Flathub as `com.github.kovidgoyal.kitty`. The terminal tools install through Homebrew. The script installs Homebrew when Bazzite does not provide it.

## License

This project uses the MIT License. See [LICENSE](LICENSE).
