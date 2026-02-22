# Reusable macOS Shortcut App Builder

Script: `./create-macos-app-shortcut.sh`

Icon support: pass `--icon /path/to/file.icns` or `--icon /path/to/file.png` (PNG auto-converts). If `icon.icns` or `icon.png` exists in repo root, it is used by default.

## Unity example (automatic version picker + auto-kill Unity Hub)

```bash
./create-macos-app-shortcut.sh \
  --name "Unity" \
  --output-dir "$HOME/Applications" \
  --overwrite \
  --unity-project-path "$HOME/path/to/your-unity-project"
```

This creates two apps in `~/Applications`:

- `Unity.app`: remembers your chosen editor version and launches directly next time.
- `Unity (Select Editor).app`: always asks again so you can change the saved version.

## Generic examples

```bash
# One-liner command
./create-macos-app-shortcut.sh \
  --name "My Task" \
  --command 'open https://example.com'

# Use a script file as command source
cat > /tmp/my-task.sh <<'TASK'
echo "Starting"
open -a "Visual Studio Code" "$HOME/project"
TASK

./create-macos-app-shortcut.sh \
  --name "Open Project" \
  --command-file /tmp/my-task.sh \
  --overwrite
```

## Move to another machine

1. Copy `create-macos-app-shortcut.sh` to that machine (for example: `~/bin/`).
2. Make it executable: `chmod +x ~/bin/create-macos-app-shortcut.sh`.
3. Run it with machine-specific paths in `--command`.
