# Radio Atlas Lite for DankMaterialShell

A lightweight **DankMaterialShell (DMS)** DankBar plugin that launches the standalone
Radio Atlas Lite Quickshell app. Click the Radio Atlas icon in DankBar and the same app
available through `./run.sh` opens.

This project intentionally keeps the Lite feature set unchanged.

## Requirements

- DankMaterialShell / Quickshell
- `mpv`

# Install MPV
    # Fedora
    sudo dnf install mpv
    other distributions: https://mpv.io/installation/

No `jq`, `curl`, `socat`, `bubblewrap`, Python helper, proxy daemon, or Omarchy runtime is required.

## Install manually for testing

Clone this repository directly into the DMS plugin directory:

```bash
mkdir -p ~/.config/DankMaterialShell/plugins
git clone <your-repository-url> ~/.config/DankMaterialShell/plugins/RadioAtlasLite
dms restart
```

Then enable **Radio Atlas Lite** under DMS Plugins and add it to DankBar.

You can also launch the bundled app directly:

```bash
~/.config/DankMaterialShell/plugins/RadioAtlasLite/run.sh
```

After this plugin is accepted into the official DMS plugin registry, users can install it with:

```bash
dms plugins install radioAtlasLite
```

## Repository structure

```text
.
├── plugin.json
├── Widget.qml
├── run.sh
├── shell.qml
├── AppButton.qml
├── Globe.qml
├── RadioModel.js
├── LICENSE
├── CREDITS.md
└── assets/
    ├── countries.json
    └── NOTICE.md
```

The repository root is the plugin root. `plugin.json` declares a DMS `widget` with the
`dankbar-widget` capability. `Widget.qml` uses DMS's plugin path API to launch the bundled
`run.sh`, so there is no hardcoded installation directory.

## Contributing this plugin to the DMS registry

The plugin itself stays in **this repository**. Do not copy these QML/app files into the
DMS registry repository.

To submit it to the registry:

1. Push this repository to GitHub and keep `plugin.json` at the repository root.
2. Add a real `screenshot.png` to this repository showing Radio Atlas Lite running.
3. Fork `AvengeMedia/dms-plugin-registry`.
4. In your registry fork, create `plugins/<github-username>-radio-atlas-lite.json`.
5. Copy the registry JSON template supplied separately with this project, replace the GitHub
   username/repository placeholders, and use a direct URL to your `screenshot.png`.
6. Run the registry validation commands from its `CONTRIBUTING.md`.
7. Commit that single registry JSON file and open a PR to `AvengeMedia/dms-plugin-registry`.

The registry entry's `id` and `name` must exactly match this repository's `plugin.json`:

```text
id:   radioAtlasLite
name: Radio Atlas Lite
```

## Credits / upstream

Radio Atlas Lite is a lightweight DMS/Quickshell adaptation of **Radio Atlas** by
**Akshar Patel**:

https://github.com/AksharP5/omarchy-radio-atlas

The original project's MIT `LICENSE` is retained unchanged. The rotatable globe concept,
Radio Browser integration, map assets/data approach, and basis of this Lite adaptation come
from the upstream project.

See [CREDITS.md](CREDITS.md) for explicit attribution. Natural Earth map data is public
domain; see `assets/NOTICE.md`.

## Security note

The Lite adaptation intentionally does not include upstream Radio Atlas's sandbox/proxy
stack. It connects `mpv` directly to community-supplied HTTP/HTTPS radio streams, so it is
less hardened than upstream.
