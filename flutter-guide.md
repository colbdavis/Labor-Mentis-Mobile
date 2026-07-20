# Flutter development guide

## Installed development environment

| Component | Location / version |
| --- | --- |
| Flutter | `~/.local/flutter` (3.44.6 stable) |
| Dart | Bundled with Flutter (3.12.2) |
| Android SDK | `~/Android/Sdk` |
| Android target | API 36; build-tools 36.0.0 |
| Java | OpenJDK 17 (`jdk17-openjdk`) |
| Shell | zsh; configuration in `~/.zshrc` |

The Android command-line tools, platform tools, build tools, NDK, and CMake are installed below `~/Android/Sdk`.

## Shell configuration

The following block was appended to `~/.zshrc`:

```zsh
# Flutter and Android development
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$HOME/.local/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
```

Open a new terminal after changing it, or reload it now:

```zsh
source ~/.zshrc
```

Check the installation:

```zsh
flutter doctor
flutter --version
```

`flutter doctor` reporting that Chrome is absent is harmless for Android-only development.

## This project

The Flutter application lives in this directory. It uses Dart and Material 3 and currently contains:

- A catalog of small, built-in quiz packs.
- Four playable modes: multiple choice, true/false, text answer, and matching pairs.
- A final result screen and session-only score summary.
- A widget test that opens a built-in quiz from the catalog.

Useful files:

```text
lib/main.dart           Application UI and game logic
test/widget_test.dart   Widget test
pubspec.yaml            Flutter project configuration
android/                Android app and Gradle configuration
```

## Daily workflow

From the project root:

```zsh
flutter pub get       # Fetch dependencies after pubspec.yaml changes
flutter run           # Build and run on a selected device
flutter analyze       # Static analysis
flutter test          # Run automated tests
dart format lib test  # Format Dart source
flutter build apk --debug  # Create a debug Android APK
```

The debug APK is written to:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

While `flutter run` is active:

- Press `r` for hot reload after UI/code edits.
- Press `R` for a full hot restart (resets app state).
- Press `q` to stop the app.

## Using an Android phone

1. On the phone, enable **Developer options** and **USB debugging**.
2. Connect it by USB and accept the computer's debugging authorization prompt.
3. Confirm that Flutter sees it:

   ```zsh
   flutter devices
   ```

4. Run the app:

   ```zsh
   flutter run
   ```

If no phone is connected, Flutter can still target Linux desktop. An Android emulator was not installed; using a physical phone avoids its extra disk and virtualization requirements.

## Reverting PC-level changes

> These commands remove the Flutter/Android development environment and downloaded SDK data. They do **not** remove the project unless you run the optional project command.

### 1. Remove the zsh environment block

Edit `~/.zshrc` and remove exactly this block:

```zsh
# Flutter and Android development
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$HOME/.local/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
```

Then reload the shell:

```zsh
source ~/.zshrc
```

### 2. Remove Flutter and the Android SDK

```zsh
rm -rf ~/.local/flutter ~/Android/Sdk
```

This removes Flutter, Dart bundled with Flutter, Android SDK packages, licenses, NDK, and CMake downloaded for this setup.

### 3. Optionally remove Java 17

Java 17 was the only system package added. First select another installed Java version, then uninstall it:

```zsh
sudo archlinux-java status
sudo archlinux-java set java-26-openjdk
sudo pacman -Rns jdk17-openjdk
```

Only run the last two commands if `java-26-openjdk` (or another suitable Java version) appears in `archlinux-java status`. Do not remove the pre-existing `android-tools` package; it was present before this setup.

### 4. Optionally delete this project

From the directory containing the project:

```zsh
cd ..
rm -rf 'Labor Mentis - Mobile'
```
