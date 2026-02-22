# Unity Shortcut for macOS (Launch Unity Project Without Unity Hub)

<p align="center">
  <strong>Create a native macOS app shortcut that opens a Unity project directly, lets you pick installed editor versions, then closes Unity Hub automatically.</strong>
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS-black?logo=apple">
  <img alt="Shell" src="https://img.shields.io/badge/shell-bash-121011?logo=gnubash">
  <img alt="Unity" src="https://img.shields.io/badge/unity-project%20launcher-222c37?logo=unity">
  <img alt="Status" src="https://img.shields.io/badge/status-ready-success">
</p>

## Why This Exists

If you searched for any of these, you are in the right place:

- `unity shortcut mac`
- `launch unity project without unity hub`
- `unity macos app shortcut`
- `open unity project directly from finder`
- `unity independent of unity hub`

This repo provides a reusable script that builds a real `.app` bundle in `~/Applications`, so you can launch Unity projects from a desktop-style shortcut.

## What You Get

- `create-macos-app-shortcut.sh`: reusable macOS app shortcut builder
- Support for one-liner or multiline commands
- Optional custom app icon (`.icns` or `.png`, PNG auto-converted)
- Safe overwrite behavior
- Works for Unity and any other command-based workflow

## Quick Start

### 1) Make script executable

```bash
chmod +x ./create-macos-app-shortcut.sh
```

### 2) Create Unity launcher app (fully automatic)

```bash
./create-macos-app-shortcut.sh \
  --name "Unity" \
  --output-dir "$HOME/Applications" \
  --overwrite \
  --unity-project-path "$HOME/path/to/your-unity-project"
```

### 3) Launch it

Open `~/Applications/Unity.app` and run it like any normal macOS app.

At runtime, the shortcut will:

- Detect installed Unity editors under `/Applications/Unity/Hub/Editor`
- Show a picker if more than one version is installed
- Launch your selected editor with the target project
- Poll for Unity Hub and kill it as soon as it appears
- Save your selected editor and reuse it on future launches

If `icon.icns` or `icon.png` exists in this repo root, it is used automatically for both generated Unity shortcuts.
The script also creates `~/Applications/Unity (Select Editor).app` so you can re-pick the editor version anytime.

## How It Works

`create-macos-app-shortcut.sh` builds a native `.app` structure:

| Path | Purpose |
|---|---|
| `YourApp.app/Contents/MacOS/launcher` | Executable shell launcher |
| `YourApp.app/Contents/Info.plist` | macOS app metadata |
| `YourApp.app/Contents/Resources` | Optional icon assets |

The launcher runs your embedded shell command block exactly as provided.

## Script Usage

```bash
./create-macos-app-shortcut.sh --name "App Name" --command 'echo hi'
./create-macos-app-shortcut.sh --name "App Name" --command-file /path/to/script.sh
./create-macos-app-shortcut.sh --name "Unity" --unity-project-path /path/to/project
```

### Options

| Option | Description |
|---|---|
| `--name NAME` | App name (required) |
| `--command CMD` | Command(s) to run when app opens |
| `--command-file PATH` | Read commands from file |
| `--unity-project-path PATH` | Build automatic Unity launcher mode |
| `--unity-editor-root DIR` | Unity editor root (default: `/Applications/Unity/Hub/Editor`) |
| `--unity-hub-timeout SEC` | Max wait before killing Unity Hub (default: `20`) |
| `--output-dir DIR` | Destination for `.app` bundle (default: `~/Applications`) |
| `--bundle-id ID` | Custom bundle identifier |
| `--icon FILE` | Optional app icon (`.icns` or `.png`) |
| `--overwrite` | Replace existing app with same name |
| `-h`, `--help` | Show help |

## More Examples

### One-line shortcut

```bash
./create-macos-app-shortcut.sh \
  --name "Open Docs" \
  --command 'open https://docs.unity3d.com/'
```

### Command file shortcut

```bash
cat > /tmp/open-project.sh <<'TASK'
echo "Starting project"
open -a "Visual Studio Code" "$HOME/path/to/your-project"
TASK

./create-macos-app-shortcut.sh \
  --name "Open Project" \
  --command-file /tmp/open-project.sh \
  --overwrite
```

## Troubleshooting

### Unity editors not found

If your Unity editors are in a custom location, set:

```bash
--unity-editor-root "/your/custom/unity/editor/root"
```

### Unity Hub not killed in time

Increase timeout:

```bash
--unity-hub-timeout 30
```

### Existing app not replaced

Use `--overwrite`.

## Search keys

This project is intentionally optimized for developers searching for:

- Unity shortcut macOS
- Unity launcher app
- Run Unity without Unity Hub
- Unity project direct launch
- macOS app wrapper for shell command
