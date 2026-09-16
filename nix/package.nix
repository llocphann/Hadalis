{ pkgs }:

let
  lib = pkgs.lib;
  packageVersion = lib.removeSuffix "\n" (builtins.readFile ../VERSION);

  optionalTop = name:
    lib.optional (builtins.hasAttr name pkgs) (builtins.getAttr name pkgs);

  optionalKde = name:
    lib.optional
      (builtins.hasAttr "kdePackages" pkgs && builtins.hasAttr name pkgs.kdePackages)
      (builtins.getAttr name pkgs.kdePackages);

  optionalQt6 = name:
    lib.optional
      (builtins.hasAttr "qt6" pkgs && builtins.hasAttr name pkgs.qt6)
      (builtins.getAttr name pkgs.qt6);

  runtimeDeps =
    with pkgs; [
      bash
      bc
      coreutils
      curl
      findutils
      gawk
      git
      gnugrep
      gnused
      jq
      procps
      python3
      ripgrep
      rsync
      systemd
      wget
      xdg-user-dirs
      xdg-utils

      quickshell
      wl-clipboard
      cliphist
      grim
      slurp
      playerctl
      libnotify
      glib
      pipewire
      pulseaudio
      wireplumber
    ]
    ++ optionalTop "brightnessctl"
    ++ optionalTop "cava"
    ++ optionalTop "ddcutil"
    ++ optionalTop "ffmpeg"
    ++ optionalTop "fish"
    ++ optionalTop "foot"
    ++ optionalTop "fuzzel"
    ++ optionalTop "geoclue2"
    ++ optionalTop "hyprland"
    ++ optionalTop "hyprpicker"
    ++ optionalTop "gum"
    ++ optionalTop "imagemagick"
    ++ optionalTop "kitty"
    ++ optionalTop "libqalculate"
    ++ optionalTop "mpv"
    ++ optionalTop "nautilus"
    ++ optionalTop "networkmanager"
    ++ optionalTop "socat"
    ++ optionalTop "songrec"
    ++ optionalTop "swappy"
    ++ optionalTop "tesseract"
    ++ optionalTop "translate-shell"
    ++ optionalTop "upower"
    ++ optionalTop "wf-recorder"
    ++ optionalTop "wlsunset"
    ++ optionalTop "wtype"
    ++ optionalTop "xwayland-satellite"
    ++ optionalTop "ydotool"
    ++ optionalKde "breeze-icons"
    ++ optionalKde "kdialog"
    ++ optionalKde "kirigami"
    ++ optionalKde "kconfig"
    ++ optionalKde "plasma-integration"
    ++ optionalKde "syntax-highlighting"
    ++ optionalKde "xembedsniproxy"
    ++ optionalQt6 "qt5compat"
    ++ optionalQt6 "qtbase"
    ++ optionalQt6 "qtdeclarative"
    ++ optionalQt6 "qtimageformats"
    ++ optionalQt6 "qtmultimedia"
    ++ optionalQt6 "qtpositioning"
    ++ optionalQt6 "qtquicktimeline"
    ++ optionalQt6 "qtsensors"
    ++ optionalQt6 "qtsvg"
    ++ optionalQt6 "qttools"
    ++ optionalQt6 "qttranslations"
    ++ optionalQt6 "qtvirtualkeyboard"
    ++ optionalQt6 "qtwayland";

  materialSymbolsFont =
    if builtins.hasAttr "material-symbols" pkgs
    then pkgs.makeFontsConf { fontDirectories = [ pkgs.material-symbols ]; }
    else null;
  materialSymbolsWrapperArg =
    lib.optionalString (materialSymbolsFont != null)
      "--set FONTCONFIG_FILE \"${materialSymbolsFont}\" \\";

  qmlDeps =
    # kirigami-wrapped ships no QML files, use the unwrapped version.
    (lib.optional
      (builtins.hasAttr "kdePackages" pkgs && builtins.hasAttr "kirigami" pkgs.kdePackages)
      pkgs.kdePackages.kirigami.passthru.unwrapped)
    ++ optionalKde "syntax-highlighting"
    ++ optionalQt6 "qt5compat"
    ++ optionalQt6 "qtdeclarative"
    ++ optionalQt6 "qtimageformats"
    ++ optionalQt6 "qtmultimedia"
    ++ optionalQt6 "qtpositioning"
    ++ optionalQt6 "qtquicktimeline"
    ++ optionalQt6 "qtsensors"
    ++ optionalQt6 "qtsvg"
    ++ optionalQt6 "qtvirtualkeyboard"
    ++ optionalQt6 "qtwayland";
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "inir";
  version = packageVersion;
  src = lib.cleanSource ../.;

  nativeBuildInputs = [ pkgs.makeWrapper pkgs.python3 pkgs.rsync ];

  # Prevent patchShebangs from attempting to rewrite Python scripts;
  # non-executable files are skipped during fixupPhase.
  preFixup = ''
    find "$out/share/quickshell/inir" -type f -name '*.py' -exec chmod -x {} +
  '';

  postFixup = ''
    find "$out/share/quickshell/inir" -type f -name '*.py' -exec chmod +x {} +
  '';

  installPhase = ''
    runHook preInstall

    runtime="$out/share/quickshell/inir"
    mkdir -p "$runtime" "$out/bin"

    python3 sdata/lib/runtime-payload.py copy --root . --target "$runtime"

    chmod +x "$runtime/setup" "$runtime/scripts/inir"
    find "$runtime/scripts" -type f \( -name '*.sh' -o -name '*.fish' -o -name '*.py' \) -exec chmod +x {} \;

    # The source tree intentionally targets Arch, where helpers live under
    # /usr/bin. NixOS does not provide that layout. Patch only the packaged
    # copy and keep shebang lines intact.
    find "$runtime/modules" "$runtime/services" "$runtime/defaults" "$runtime/scripts" \
      -type f \( -name '*.qml' -o -name '*.js' -o -name '*.sh' -o -name '*.py' \) \
      -exec sed -i '1!s#/usr/bin/##g' {} +

    cat > "$runtime/version.json" <<'EOF'
{
  "version": "${packageVersion}",
  "commit": "nix-package",
  "installed_at": "nix-store",
  "installedAt": "nix-store",
  "source": "nix",
  "repo_path": "",
  "repoPath": "",
  "install_mode": "package-managed",
  "installMode": "package-managed",
  "update_strategy": "package-manager",
  "updateStrategy": "package-manager",
  "package_manager": "nix",
  "packageManager": "nix",
  "package_name": "inir",
  "packageName": "inir",
  "package_update_hint": "update the Hadalis source/input and rebuild your NixOS or Home Manager configuration",
  "packageUpdateHint": "update the Hadalis source/input and rebuild your NixOS or Home Manager configuration"
}
EOF

    makeWrapper "$runtime/scripts/inir" "$out/bin/inir" \
      --prefix PATH : "${lib.makeBinPath runtimeDeps}" \
      --prefix QML2_IMPORT_PATH : "${lib.makeSearchPath "lib/qt-6/qml" qmlDeps}" \
      --prefix QT_PLUGIN_PATH : "${lib.makeSearchPath "lib/qt-6/plugins" qmlDeps}" \
      ${materialSymbolsWrapperArg}
      --set-default INIR_SYSTEM_RUNTIME_DIR "$runtime" \
      --set-default INIR_FALLBACK_SYSTEM_RUNTIME_DIR "$runtime"

    runHook postInstall
  '';

  passthru.runtimeDependencies = runtimeDeps;

  meta = {
    description = "Hadalis desktop shell runtime built on Quickshell";
    homepage = "https://github.com/llocphann/Hadalis";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "inir";
  };
}
