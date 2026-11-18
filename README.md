# InTrique Website

Marketing and download website for the InTrique client. The site is plain
HTML/CSS/JavaScript served from the repository root so GitHub Pages can host it
directly. A small Node static server is included for local development, and the
Windows release pipeline builds the client, compiles the installer, creates the
GitHub release, and publishes the site.

## Current state (2026-11-18)

This section records the exact state of the project at the time of the last
update. It is the fastest way to see what is shipped, what is installed, and
what still needs attention.

### Shipped release

| Field | Value |
| --- | --- |
| Version | `0.1.2` (tag `v0.1.2`) |
| Released | 2026-11-18 |
| Platform | `windows-x64` |
| Installer | `downloads/InTrique-Setup.exe` — 7,476,773 bytes |
| SHA-256 | `49be2036f5d9ec4093265b18644bc7647f47e3ee81c7edd6d6a4923bbc017ddd` |
| Installer URL | `https://github.com/InTrique-Owner/InTrique.web/releases/download/v0.1.2/InTrique-Setup.exe` |
| Client URL | `https://github.com/InTrique-Owner/InTrique.web/releases/download/v0.1.2/InTriqueClient.exe` |

`release/latest.json` is generated from the actual installer by
`scripts\build-release.bat`; it is not edited by hand. It now stores full GitHub
release URLs rather than relative paths, and no longer contains the old `tag`,
`url`, or `size_display` fields.

### Git state

- Branch: `main`; remote: `https://github.com/InTrique-Owner/InTrique.web.git`.
- Last pushed commit: `c291593 Add global UPD command installer and docs`.
- `main` and `origin/main` were in sync (`0 0`) at the time of this update.
- Remote commits are always fetched and merged — never force-pushed.

The following release-run files are currently modified in the working tree and
have **not** been committed or published yet:

```
README.md
downloads/InTrique-Setup.exe
release/latest.json
scripts/build-release.bat
scripts/publish-website.bat
scripts/publish.bat
scripts/ui.ps1
sitemap.xml
```

### Toolchain installed on this machine

| Tool | Version / location |
| --- | --- |
| Git | 2.55.0.windows.5 — `C:\Program Files\Git\cmd\git.exe` |
| Node.js | v26.12.1 |
| CMake | 3.30.4 |
| Ninja | 1.12.1 |
| GitHub CLI (`gh`) | 2.104.0 — `C:\Program Files\GitHub CLI\gh.exe`, authenticated |
| Windows PowerShell | 5.1 — `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe` |
| Inno Setup 7 | `%LOCALAPPDATA%\Programs\Inno Setup 7\ISCC.exe` |
| Client source | `C:\InTrique\CMakeLists.txt` exists |

CMake, Ninja, and `gh` were previously missing and are now available, which
unblocks a full release. `INNO_SETUP_COMPILER` and `INTRIQUE_PROJECT` can be set
to override the Inno Setup compiler and the C++ source location.

### Live website

GitHub Pages: <https://intrique-owner.github.io/InTrique.web/>

- `/terms.html`, `/privacy.html`, and `/download.html` were verified in Edge.
- The legal pages had a stacking bug where an ambient background layer covered
  the text. Fixed in `assets\css\pages.css` with `position: relative;
  z-index: 1` on `.page-hero`, `.dl-section`, and `.legal-section`. Text is now
  visible immediately on load.

### Release console and UPD

- `UPD` is a global command: `%LOCALAPPDATA%\Intrique\bin\UPD.bat` was created
  and its folder added to the **user PATH**. It forwards all arguments to
  `scripts\publish.bat` and works from any directory in cmd and PowerShell
  (verified from `C:\Windows\Temp`). Open a new terminal after installing.
- The console is `scripts\ui.ps1`: a single solid `#050505` full-terminal
  background, the InTrique ASCII mark, four actions, and keyboard selection
  with a live one-line description of the highlighted action.
- Chakra Petch (Regular + Bold) is bundled in `assets\fonts\` with its OFL
  license. It is installed per-user and applied to the console on the first
  non-snapshot launch.
- Child build/publish output is colorized as it streams: errors red, warnings
  amber, stage markers and success white, general output light gray.
- `Invoke-Batch` runs each child script from the repo root with
  `cmd /d /s /c`, sets `$ErrorActionPreference = 'Continue'` so native tools
  such as Git can write normal messages to stderr without aborting the script,
  captures `$LASTEXITCODE` immediately, and restores the location and preference
  in a `finally` block.

### Known inconsistencies / next steps

1. `index.html` still contains a hardcoded `RELEASE` object for **v0.1.1** with
   the old checksum and a relative download URL. The rewritten
   `build-release.bat` no longer updates `index.html`, so the home-page release
   card is stale until it is updated.
2. `download.html` still reads `meta.size_display` and `meta.url`. Those fields
   were removed from `latest.json`, so the download page shows `undefined` for
   the size and its download handler falls back to the relative path instead of
   the new GitHub release URL. It should read `meta.size` and `meta.installer`.
3. The v0.1.2 release-run changes listed above still need to be committed and
   pushed (`UPD -Choice 2`) so the live site serves the new metadata.

None of these were changed as part of this README update — they are recorded
here so they can be addressed deliberately.

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
│   ├── publish.bat            Launcher for the release console
│   ├── ui.ps1                 Full-screen release console (logo, actions, keys)
│   ├── install-upd-command.ps1 Installs the global UPD command
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

All scripts live in `scripts/` and are intended to be run from Windows. The
pipeline is split into two phases: the **builder** compiles the client and
publishes the GitHub release, and the **publisher** commits and pushes the
website to GitHub Pages.

- `scripts\publish.bat` — opens the release console. It shows the InTrique
  mark, four pipeline actions, and keyboard hints on a single solid dark
  background that fills the terminal, with the website's white/graphite palette.
  The console uses Chakra Petch (installed per-user from `assets/fonts/` on
  first launch) and colors build output by type: errors red, warnings amber,
  progress white, and general output light gray.
- `scripts\build-release.bat` — validates the version (`set "ver=0.1.2"` at the
  top; change it for each release), checks tools and GitHub authentication,
  configures and builds the CMake client, stages and verifies the executable,
  compiles `installer\InTrique.iss` with Inno Setup, regenerates
  `release/latest.json` with full GitHub release URLs, creates or overwrites
  the GitHub release with `--clobber`, and verifies the uploaded assets. It
  does **not** commit website files any more — that is the publisher's job.
- `scripts\publish-website.bat` — verifies the repository root, remote, branch,
  and release files; fetches and refuses to publish if the local branch is
  behind GitHub (no force-push); stages the site and force-adds the EXE files;
  commits, pushes, and verifies that the local and remote commit IDs match.

### Release console

```bat
UPD
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
UPD -Snapshot    render the console once and exit
UPD -Choice 1    run one action (1-4), then exit
UPD -h           show usage
```

### Global UPD command

Run the installer once:

```bat
powershell -ExecutionPolicy Bypass -File scripts\install-upd-command.ps1
```

It creates `%LOCALAPPDATA%\Intrique\bin\UPD.bat` and adds that folder to your
user PATH. Open a new terminal, then type `UPD` from any directory to launch the
release console.

The console runs the existing batch scripts as child processes, so their build
logs appear inline. A success or failure line and the exit code are shown when
each action finishes. The action list is:

1. Build the client and publish a GitHub release.
2. Publish the website only.
3. Full synchronized release (build, then publish).
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
hand. It contains:

```json
{
  "version": "0.1.2",
  "released": "2026-11-18",
  "platform": "windows-x64",
  "installer": "https://github.com/.../releases/download/v0.1.2/InTrique-Setup.exe",
  "client": "https://github.com/.../releases/download/v0.1.2/InTriqueClient.exe",
  "size": 7476773,
  "sha256": "49be2036f5d9ec4093265b18644bc7647f47e3ee81c7edd6d6a4923bbc017ddd"
}
```

`download.html` fetches this file at runtime so the displayed version and
download link stay in sync with the GitHub release. See "Known inconsistencies"
above for the fields that still need to be reconciled.

## Notes

- Keep the site files at the repository root; GitHub Pages publishes from
  there.
- `downloads/` is served as-is by the Node server and hosted alongside the
  website.
- The installer script expects artwork in `installer/assets/` and writes its
  output to `downloads/`.
- Never force-push: remote release commits are merged so no work is discarded.
