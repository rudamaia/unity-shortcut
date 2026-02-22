#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  create-macos-app-shortcut.sh --name "App Name" --command 'echo hi'
  create-macos-app-shortcut.sh --name "App Name" --command-file /path/to/script.sh
  create-macos-app-shortcut.sh --name "Unity" --unity-project-path /path/to/project

Options:
  --name NAME                  App bundle display name (required)
  --command CMD                Command(s) to run when app is opened
  --command-file PATH          File containing command(s) to run
  --unity-project-path PATH    Build a self-contained Unity launcher app
  --unity-editor-root DIR      Unity Hub editor root (default: /Applications/Unity/Hub/Editor)
  --unity-hub-timeout SEC      How long to wait for Unity Hub before killing it (default: 20)
  --output-dir DIR             Destination for .app bundle (default: $HOME/Applications)
  --bundle-id ID               CFBundleIdentifier (default: local.shortcut.<sanitized-name>)
  --icon FILE                  Optional icon (.icns or .png) to copy into app bundle
  --overwrite                  Replace existing app with same name
  -h, --help                   Show this help
USAGE
}

name=""
command_text=""
command_file=""
unity_project_path=""
unity_editor_root="/Applications/Unity/Hub/Editor"
unity_hub_timeout="20"
output_dir="${HOME}/Applications"
bundle_id=""
icon_path=""
overwrite=0
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
prepared_icon_path=""
generated_icon_tmp=""

cleanup_generated_icon() {
  if [[ -n "$generated_icon_tmp" && -e "$generated_icon_tmp" ]]; then
    rm -rf "$generated_icon_tmp"
  fi
}
trap cleanup_generated_icon EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      name="${2:-}"
      shift 2
      ;;
    --command)
      command_text="${2:-}"
      shift 2
      ;;
    --command-file)
      command_file="${2:-}"
      shift 2
      ;;
    --unity-project-path)
      unity_project_path="${2:-}"
      shift 2
      ;;
    --unity-editor-root)
      unity_editor_root="${2:-}"
      shift 2
      ;;
    --unity-hub-timeout)
      unity_hub_timeout="${2:-}"
      shift 2
      ;;
    --output-dir)
      output_dir="${2:-}"
      shift 2
      ;;
    --bundle-id)
      bundle_id="${2:-}"
      shift 2
      ;;
    --icon)
      icon_path="${2:-}"
      shift 2
      ;;
    --overwrite)
      overwrite=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$name" ]]; then
  echo "Error: --name is required" >&2
  exit 1
fi

safe_name="$(printf '%s' "$name" | tr -cs '[:alnum:].-' '-')"
safe_name="${safe_name#-}"
safe_name="${safe_name%-}"
if [[ -z "$safe_name" ]]; then
  safe_name="shortcut"
fi
safe_name_lower="$(printf '%s' "$safe_name" | tr '[:upper:]' '[:lower:]')"

if [[ -z "$bundle_id" ]]; then
  bundle_id="local.shortcut.${safe_name_lower}"
fi

if [[ -n "$command_text" && -n "$command_file" ]]; then
  echo "Error: use either --command or --command-file, not both" >&2
  exit 1
fi

if [[ -n "$unity_project_path" && ( -n "$command_text" || -n "$command_file" ) ]]; then
  echo "Error: --unity-project-path cannot be combined with --command/--command-file" >&2
  exit 1
fi

if [[ -n "$command_file" ]]; then
  if [[ ! -f "$command_file" ]]; then
    echo "Error: command file not found: $command_file" >&2
    exit 1
  fi
  command_text="$(cat "$command_file")"
fi

find_unity_icon() {
  local root="$1"
  local candidate

  for candidate in "$root"/*/Unity.app/Contents/Resources/Unity.icns; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  for candidate in "$root"/*/Unity.app/Contents/Resources/AppIcon.icns; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

prepare_icon() {
  local source_icon="$1"
  local out_icns

  if [[ -z "$source_icon" ]]; then
    prepared_icon_path=""
    return 0
  fi

  if [[ ! -f "$source_icon" ]]; then
    echo "Error: icon file not found: $source_icon" >&2
    exit 1
  fi

  case "$source_icon" in
    *.icns)
      prepared_icon_path="$source_icon"
      return 0
      ;;
    *.png|*.PNG)
      if ! command -v sips >/dev/null 2>&1; then
        echo "Error: sips not found; required to convert PNG icons" >&2
        exit 1
      fi
      # Use /tmp explicitly to avoid write failures in some per-session TMPDIR paths.
      generated_icon_tmp="$(mktemp -d /tmp/unity-shortcut-icon.XXXXXX)"
      out_icns="${generated_icon_tmp}/AppIcon.icns"
      if ! TMPDIR=/tmp sips -s format icns "$source_icon" --out "$out_icns" >/dev/null 2>&1; then
        echo "Error: failed to convert PNG icon to ICNS with sips." >&2
        echo "Hint: run 'sips -s format icns \"$source_icon\" --out \"${script_dir}/icon.icns\"' and retry." >&2
        exit 1
      fi
      prepared_icon_path="$out_icns"
      return 0
      ;;
    *)
      echo "Error: unsupported icon format: $source_icon (use .icns or .png)" >&2
      exit 1
      ;;
  esac
}

build_unity_command() {
  local force_pick="$1"
  local project_escaped editor_root_escaped selection_file_escaped

  project_escaped="$(printf '%q' "$unity_project_path")"
  editor_root_escaped="$(printf '%q' "$unity_editor_root")"
  selection_file_escaped="$(printf '%q' "$HOME/Library/Application Support/UnityShortcut/${safe_name_lower}.selected_editor")"

  cat <<UNITY_COMMAND
project_path=${project_escaped}
editor_root=${editor_root_escaped}
hub_timeout=${unity_hub_timeout}
selection_file=${selection_file_escaped}
force_pick=${force_pick}

show_error() {
  /usr/bin/osascript -e 'display alert "Unity Shortcut" message "'"\$1"'" as critical'
}

editors=()
for candidate in "\$editor_root"/*/Unity.app/Contents/MacOS/Unity; do
  if [[ -x "\$candidate" ]]; then
    editors+=("\$candidate")
  fi
done

if [[ \${#editors[@]} -eq 0 ]]; then
  show_error "No Unity editor was found in \$editor_root"
  exit 1
fi

selected_bin=""

if [[ "\$force_pick" != "1" && -f "\$selection_file" ]]; then
  cached_bin="\$(cat "\$selection_file" 2>/dev/null || true)"
  cached_bin="\$(printf '%s' "\$cached_bin" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  if [[ -n "\$cached_bin" && -x "\$cached_bin" ]]; then
    selected_bin="\$cached_bin"
  fi
fi

if [[ -z "\$selected_bin" ]]; then
  if [[ \${#editors[@]} -eq 1 ]]; then
    selected_bin="\${editors[0]}"
  else
    labels=()
    for bin in "\${editors[@]}"; do
      version="\$(basename "\$(dirname "\$(dirname "\$(dirname "\$(dirname "\$bin")")")")")"
      labels+=("\$version")
    done

    choice="\$(/usr/bin/osascript - "\${labels[@]}" <<'OSA'
on run argv
  set picked to choose from list argv with title "Unity Shortcut" with prompt "Choose Unity editor version" without multiple selections allowed
  if picked is false then
    return "__CANCELLED__"
  end if
  return item 1 of picked
end run
OSA
)"

    choice="\$(printf '%s' "\$choice" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    if [[ -z "\$choice" || "\$choice" == "__CANCELLED__" ]]; then
      exit 0
    fi

    for idx in "\${!labels[@]}"; do
      if [[ "\${labels[\$idx]}" == "\$choice" ]]; then
        selected_bin="\${editors[\$idx]}"
        break
      fi
    done

    if [[ -z "\$selected_bin" ]]; then
      show_error "Unable to match selected Unity version: \$choice"
      exit 1
    fi
  fi
fi

mkdir -p "\$(dirname "\$selection_file")"
printf '%s\n' "\$selected_bin" > "\$selection_file"

"\$selected_bin" -projectPath "\$project_path" >/dev/null 2>&1 &

end_time=\$((\$(date +%s) + hub_timeout))
while [[ \$(date +%s) -le \$end_time ]]; do
  if /usr/bin/pgrep -f "Unity Hub" >/dev/null 2>&1; then
    /usr/bin/pkill -f "Unity Hub" >/dev/null 2>&1 || true
    break
  fi
  /bin/sleep 0.2
done
UNITY_COMMAND
}

write_app() {
  local app_name="$1"
  local app_bundle_id="$2"
  local app_command="$3"
  local app_dir macos_dir resources_dir launcher_path plist_path icon_key

  app_dir="${output_dir}/${app_name}.app"
  macos_dir="${app_dir}/Contents/MacOS"
  resources_dir="${app_dir}/Contents/Resources"
  launcher_path="${macos_dir}/launcher"
  plist_path="${app_dir}/Contents/Info.plist"

  if [[ -e "$app_dir" ]]; then
    if [[ "$overwrite" -ne 1 ]]; then
      echo "Error: ${app_dir} already exists. Re-run with --overwrite to replace it." >&2
      exit 1
    fi
    rm -rf "$app_dir"
  fi

  mkdir -p "$macos_dir" "$resources_dir"

  cat > "$launcher_path" <<'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail

# Run exactly the command block embedded at generation time.
/usr/bin/env bash <<'SHORTCUT_COMMAND'
LAUNCHER

  printf '%s\n' "$app_command" >> "$launcher_path"

  cat >> "$launcher_path" <<'LAUNCHER_END'
SHORTCUT_COMMAND
LAUNCHER_END

  chmod +x "$launcher_path"

  icon_key=""
  if [[ -n "$prepared_icon_path" ]]; then
    cp "$prepared_icon_path" "${resources_dir}/AppIcon.icns"
    icon_key=$'  <key>CFBundleIconFile</key>\n  <string>AppIcon</string>'
  fi

  cat > "$plist_path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>launcher</string>
  <key>CFBundleIdentifier</key>
  <string>${app_bundle_id}</string>
  <key>CFBundleName</key>
  <string>${app_name}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
${icon_key}
</dict>
</plist>
PLIST

  echo "Created: ${app_dir}"
}

mkdir -p "$output_dir"

if [[ -z "$icon_path" ]]; then
  if [[ -f "${script_dir}/icon.icns" ]]; then
    icon_path="${script_dir}/icon.icns"
  elif [[ -f "${script_dir}/icon.png" ]]; then
    icon_path="${script_dir}/icon.png"
  fi
fi

if [[ -n "$unity_project_path" ]]; then
  if [[ ! -d "$unity_project_path" ]]; then
    echo "Error: Unity project path not found: $unity_project_path" >&2
    exit 1
  fi
  if ! [[ "$unity_hub_timeout" =~ ^[0-9]+$ ]]; then
    echo "Error: --unity-hub-timeout must be an integer (seconds)" >&2
    exit 1
  fi

  if [[ -z "$icon_path" ]]; then
    auto_icon="$(find_unity_icon "$unity_editor_root" || true)"
    if [[ -n "$auto_icon" ]]; then
      icon_path="$auto_icon"
      echo "Using Unity icon: ${icon_path}"
    fi
  fi

  prepare_icon "$icon_path"

  main_command="$(build_unity_command 0)"
  select_command="$(build_unity_command 1)"

  write_app "$name" "$bundle_id" "$main_command"
  write_app "${name} (Select Editor)" "${bundle_id}.select" "$select_command"
  echo "Launcher: ${output_dir}/${name}.app/Contents/MacOS/launcher"
  echo "Selector: ${output_dir}/${name} (Select Editor).app/Contents/MacOS/launcher"
  exit 0
fi

if [[ -z "$command_text" ]]; then
  echo "Error: provide --command, --command-file, or --unity-project-path" >&2
  exit 1
fi

prepare_icon "$icon_path"

write_app "$name" "$bundle_id" "$command_text"
echo "Launcher: ${output_dir}/${name}.app/Contents/MacOS/launcher"
