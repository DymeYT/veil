# Veil screen saver

Veil uses the current desktop artwork and palette in a native macOS screen saver.
A slow Core Animation drift runs while the screen saver is active. The settings
preview and Reduce Motion use a still image. There is no Veil screen saver
process in the background while you work.

Build and install in your user account.

```sh
./screensaver/build.sh "$HOME/Library/Screen Savers"
```

Select **Veil** under Screen Saver in System Settings and click **Preview** to
verify that macOS loads it. Screen saver and lock timing remain in System
Settings.

The screen saver reads the palette and artwork from `~/.config/veil` when it
opens. For macOS screen saver hosts that restrict access to user files, Veil
publishes the current palette and artwork to a private per-user directory
under `/Users/Shared` when a theme is applied or restored. The signed bundle
also carries an installation snapshot. Where no wallpaper is available, Veil
uses a solid theme surface. Copies of local wallpapers are for personal use.

After a manual build, publish the current theme to the screen saver host.

```sh
python3 screensaver/sync.py "$HOME/.config/veil"
```

To remove it, select a different screen saver in System Settings and remove
`~/Library/Screen Savers/Veil.saver`. Remove the published appearance with
`python3 screensaver/sync.py "$HOME/.config/veil" --remove`.
