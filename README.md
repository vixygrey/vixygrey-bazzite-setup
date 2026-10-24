# Vixygrey Bazzite Setup

Install a Dracula Sakura desktop and terminal setup on Bazzite.

The script installs Kitty from its official Linux binary distribution and Discord, Bitwarden, and Google Chrome through Flathub. It installs terminal tools through Homebrew. It configures the supported desktop and terminal applications.

## Included components

- Kitty with a Dracula Sakura color palette.
- Discord, Bitwarden, and Google Chrome.
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

Kitty installs through its [official binary installer](https://sw.kovidgoyal.net/kitty/binary/) into `~/.local/kitty.app`, without launching during setup. The script links `kitty` and `kitten` into `~/.local/bin`, installs desktop entries with absolute executable and icon paths, and configures `kitty.desktop` as the terminal preference. Ensure `~/.local/bin` is on your PATH to use these commands from a shell. Kitty settings are written to `${XDG_CONFIG_HOME:-$HOME/.config}/kitty/kitty.conf`; desktop entries respect `XDG_DATA_HOME`.

Discord (`com.discordapp.Discord`), Bitwarden (`com.bitwarden.desktop`), and Google Chrome (`com.google.Chrome`) install from Flathub for the current user. The terminal tools install through Homebrew. The script installs Homebrew when Bazzite does not provide it.

If an earlier run failed because Flathub could not find Kitty, rerun the updated setup script. It no longer requests the unavailable `com.github.kovidgoyal.kitty` Flatpak. As with any rerun, back up existing configuration first.

## License

This project uses the MIT License. See [LICENSE](LICENSE).
