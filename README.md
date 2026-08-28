# Spotify for Omarchy

A Spotify-only bar widget for the [Omarchy 4](https://omarchy.org) shell. The bar
shows a single Spotify glyph that dims while Spotify is closed and lights up in
the theme accent color while it is playing. Clicking it opens a flyout panel with
album art, track info, a seek bar, and transport controls.

Inspired by [garak](https://github.com/BitYoungjae/garak), rewritten as a native
`omarchy-shell` plugin so it lives inside the running shell instead of spawning a
separate process.

## Requirements

- Omarchy 4 (`omarchy-shell`)
- A Nerd Font for the bar glyphs (Omarchy ships one by default)
- Spotify — `omarchy-launch-spotify` installs it on first click if missing

## Install

```bash
omarchy plugin add https://github.com/BitYoungjae/byj-omarchy-spotify.git --enable
```

Or by hand:

```bash
git clone https://github.com/BitYoungjae/byj-omarchy-spotify.git \
  ~/.config/omarchy/plugins/byj.spotify
omarchy-shell shell rescanPlugins
omarchy plugin enable byj.spotify
```

Move it around the bar with `omarchy bar move byj.spotify --section right`.

## Interactions

| Input | Action |
| --- | --- |
| Left click | Open the flyout panel — or launch Spotify when it is closed |
| Right click | Play / pause |
| Middle click | Launch or focus the Spotify window |
| Scroll up / down | Previous / next track |
| Click the album art | Focus the Spotify window |

## Bar states

| Spotify | Icon |
| --- | --- |
| Not running | Dimmed |
| Paused | Normal bar foreground |
| Playing | Accent color |

## Settings

Settings are inline on the widget's entry in `~/.config/omarchy/shell.json`:

```json
{
  "bar": {
    "layout": {
      "center": [
        { "id": "byj.spotify", "accentColor": "spotify", "albumArtSize": 96 }
      ]
    }
  }
}
```

| Key | Default | Meaning |
| --- | --- | --- |
| `accentColor` | `"theme"` | `"theme"` follows `Color.accent`, `"spotify"` pins `#1DB954`, or pass a `#RRGGBB` hex |
| `albumArtSize` | `84` | Album art edge length, in unscaled pixels |
| `panelWidth` | `340` | Flyout panel width, in unscaled pixels |
| `launchCommand` | `"omarchy-launch-spotify"` | Command run to launch or focus Spotify |
| `hideWhenClosed` | `false` | Remove the widget from the bar while Spotify is closed, instead of dimming it |

Sizes are unscaled: the shell multiplies them by `[spacing] scale` and the font
scale from `shell.toml`, so they track the rest of the desktop.

## IPC

The widget registers a `byj.spotify` IPC target, so panel and playback actions
can be bound to keys:

```bash
omarchy-shell byj.spotify toggle       # toggle the flyout panel
omarchy-shell byj.spotify open
omarchy-shell byj.spotify close
omarchy-shell byj.spotify playPause
omarchy-shell byj.spotify next
omarchy-shell byj.spotify previous
omarchy-shell byj.spotify launch       # launch or focus Spotify
omarchy-shell byj.spotify status       # JSON: running, playing, track, position
```

Hyprland keybinding:

```
bindd = SUPER, M, Spotify panel, exec, omarchy-shell byj.spotify toggle
```

## Development

Saving a file under `~/.config/omarchy/plugins/` hot-reloads the plugin, so the
fastest loop is to work in the installed checkout directly:

```bash
git clone <your fork> ~/.config/omarchy/plugins/byj.spotify
$EDITOR ~/.config/omarchy/plugins/byj.spotify/BarWidget.qml
```

Two things to know:

- **Do not symlink the plugin directory.** The shell's file watcher does not
  follow symlinks, so edits never trigger a reload — and `omarchy plugin
  validate` rejects symlinks inside a plugin folder outright.
- After a reload the previous widget instance can keep its IPC target
  registered, so `omarchy-shell byj.spotify ...` may answer from stale state.
  `omarchy-restart-shell` clears it.

Validate before publishing:

```bash
omarchy plugin validate ~/.config/omarchy/plugins/byj.spotify
```

## License

MIT — see [LICENSE](LICENSE).
