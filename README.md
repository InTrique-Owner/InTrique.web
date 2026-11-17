# InTrique Website

Marketing and download website for the InTrique client. The site is plain
HTML/CSS/JavaScript served from the repository root so GitHub Pages can host it
directly. A small Node static server is included for local development, and the
Windows release pipeline builds the client, compiles the installer, and
publishes the site.

## Project structure

```
Intrique.web/
├── index.html                 Home page (GitHub Pages entry point)
├── download.html              Download page
├── terms.html                 Terms & Conditions
├── privacy.html               Privacy & Services
├── assets/
│   ├── css/                   global.css, index.css, pages.css
│   ├── fonts/                 Chakra Petch console font (OFL licensed)
│   ├── icons/                 favicon and logo files
│   └── images/                background images
├── downloads/
│   ├── InTrique-Setup.exe     Current installer (served to visitors)
│   ├── InTriqueClient.exe     Current client executable
│   └── archive/               Previous installer versions
├── installer/
│   ├── InTrique.iss           Inno Setup script
│   └── assets/                Installer artwork
├── release/
│   └── latest.json            Release metadata consumed by the pages
├── scripts/
│   ├── publish.bat            Launcher for the branded release console
│   ├── ui.ps1                 Full-screen release console (logo, actions, keys)
│   ├── build-release.bat      Build client, installer, metadata, GitHub release
│   └── publish-website.bat    Commit and push the website to GitHub Pages
├── server/
│   └── server.js              Local static file server
├── package.json
└── .gitignore
```

## Local development

Requires Node.js 18 or newer.

```bat
npm start
```

Then open <http://localhost:3000>. The server serves the repository root, so
`/`, `/download`, `/terms`, and `/privacy` all work without file extensions.
Set `PORT` to use a different port.

You can also run it directly:

```bat
node server/server.js
```

## Release pipeline

All scripts live in `scripts/` and are intended to be run from Windows.

- `scripts\publish.bat` — opens the release console. It shows the InTrique
  mark, four pipeline actions, and keyboard hints on a single solid dark
  background that fills the terminal, with the website's white/graphite palette.
  The console uses Chakra Petch (installed per-user from `assets/fonts/` on
  first launch) and colors build output by type: errors red, warnings amber,
  progress white, and general output light gray.
- `scripts\build-release.bat` — configures and builds the CMake project,
  compiles `installer\InTrique.iss` with Inno Setup, regenerates
  `release/latest.json`, updates `index.html`, creates or updates the GitHub
  release, and publishes the updated pages.
- `scripts\publish-website.bat` — stages all changes, commits, and pushes to
  `main` for GitHub Pages.

### Release console

```bat
scripts\publish.bat
```

| Control | Action |
| --- | --- |
| Up / Down | Move between actions |
| Enter | Run the selected action |
| 1-4 | Jump to and run an action |
| Esc | Exit the console |

Moving the selection updates the one-line description beneath the menu.

Non-interactive flags:

```bat
scripts\publish.bat -Snapshot    render the console once and exit
scripts\publish.bat -Choice 1    run one action (1-4), then exit
scripts\publish.bat -h           show usage
```

The console runs the existing batch scripts as child processes, so their build
logs appear inline. A success or failure line and the exit code are shown when
each action finishes. The action list is:

1. Build the client and publish a GitHub release.
2. Publish the website only.
3. Full synchronized release.
4. Exit.

### Requirements for a full release

- CMake and Ninja in `PATH`
- [Inno Setup 7](https://jrsoftware.org/isinfo.php) (or set
  `INNO_SETUP_COMPILER` to the full path of `ISCC.exe`)
- [GitHub CLI](https://cli.github.com/) installed and authenticated
  (`gh auth login`)
- The InTrique C++ project, by default at `C:\InTrique`
  (override with the `INTRIQUE_PROJECT` environment variable)

## Release metadata

`release/latest.json` is generated from the actual installer, never edited by
hand. It contains the version, release date, installer size, SHA-256 checksum,
and download URL. Both `index.html` and `download.html` read this metadata so
the displayed version and download link stay in sync.

## Notes

- Keep the site files at the repository root; GitHub Pages publishes from
  there.
- `downloads/` is served as-is by the Node server and hosted alongside the
  website.
- The installer script expects artwork in `installer/assets/` and writes its
  output to `downloads/`.
