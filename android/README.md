# Jarvis for Android (tablet / phone)

A minimal Android app that puts the Jarvis chat UI on your tablet — no
browser needed, no computer at the moment of use.

It is a thin **WebView wrapper** around the self-contained chat page
(`app/src/main/assets/jarvis-chat.html`), which talks to the
**OpenAI-compatible API** that `jarvis serve` exposes on `:8000`.

## Two ways to run it

### Option A — Jarvis runs ON the tablet (no computer at all)

Use **Termux** (F-Droid, not Play Store) and run the engine on the device:

```bash
bash scripts/termux-install.sh
```

This installs OpenJarvis + a local llama.cpp model, starts `jarvis serve`
on `:8000`, and the app connects to `http://localhost:8000` by default.

> The model (~2 GB GGUF) downloads once. After that everything is offline.

### Option B — Jarvis runs on a computer/NAS, app is just a client

Run `jarvis serve` on your machine (SETUP.md), then in the app **Settings ⚙**
set the server address to your machine's LAN IP, e.g.
`http://192.168.1.50:8000`. The tablet chats with that Jarvis over Wi-Fi.

## Build the APK

This sandbox cannot compile the APK (no Java/Gradle/Android SDK), but the
project is complete — build it on any computer with Android Studio, or
command-line:

**Android Studio (easiest):**
1. Install Android Studio (Arctic Fox or newer).
2. `File → Open` → select this `android/` folder.
3. Let it sync Gradle, then `Build → Build Bundle(s) / APK(s) → Build APK`.
4. The APK appears at `android/app/build/outputs/apk/debug/app-debug.apk`.

**Command line:**
```bash
cd android
# one-time, if you don't have gradle:
#   download gradle 8.x, or use the wrapper:
#   ./gradlew wrapper          (if you have gradle installed once)
./gradlew assembleDebug       # produces the debug APK
```

Then install on the tablet:
```bash
# via USB / ADB:
adb install app/build/outputs/apk/debug/app-debug.apk
# or sideload: copy the .apk to the tablet and open it (allow "unknown sources")
```

## App behavior

- **⚙ Settings** — server address, model name, agent
  (`orchestrator` for full tools + memory, `simple` for fast chat).
- Server health is shown by the dot in the header (green = connected).
- Chat history is in-memory; configuration persists in the app's local
  storage.
- Uses the `orchestrator` agent by default so skills, memory and tools are
  available, matching the desktop setup.

## Why a WebView app (and not a native rewrite)?

The chat UI is a single self-contained HTML file with zero external
dependencies. Wrapping it in a WebView means the APK is tiny, builds with
only the Android SDK (no Maven dependencies), and the same UI also works in
any browser — so you can debug it on a computer before sideloading.
