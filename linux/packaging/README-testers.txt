Yomu for Linux — tester build
=============================

Works on 64-bit Linux: Ubuntu 22.04+, Debian 12+, Linux Mint 21+,
Pop!_OS 22.04+, Fedora 36+, Arch/Manjaro, openSUSE Tumbleweed.
(Tested on clean Ubuntu 22.04 and 24.04.)

INSTALL
-------
Ubuntu, Debian, Mint, Pop!_OS — use the .deb (it pulls in everything):
    sudo apt install ./yomu_*_amd64.deb

Any other distro — use the .tar.gz:
    tar xzf yomu-*-linux-x64.tar.gz
    cd yomu-*-linux-x64
    ./install.sh
  and install the helpers for voice notes, audiobooks and reminders:
    Fedora:   sudo dnf install mpv-libs ffmpeg-free pulseaudio-utils libnotify libglvnd-gles
    Arch:     sudo pacman -S mpv ffmpeg libpulse libnotify libglvnd
    openSUSE: sudo zypper install libmpv2 ffmpeg pulseaudio-utils libnotify-tools Mesa-libGLESv2-2

Then open Yomu from your app menu, or run `yomu` in a terminal.

WHAT TO TRY
-----------
- Add books: "Add books" in the Library, or right-click an EPUB/PDF in your
  file manager > Open With > Yomu, or `yomu book.epub`.
- Read: arrow keys / Space / Page Up/Down turn pages, Ctrl +/- zooms,
  Ctrl+F searches, Ctrl+D bookmarks, Esc leaves the book, F11 full screen,
  Ctrl+1..4 switch screens, Ctrl+Q quits.
- Highlight: drag across text (EPUB or PDF) — the highlight menu appears.
- Notes & voice notes: in the highlight menu pick the note icon, then HOLD
  the mic button to record (slide left to cancel, up to lock).
- Share with notes: right-click a book > Share with notes. On Linux this
  saves the file (choose where); send it to someone, they open it in Yomu.
- Reminders (Settings): desktop notifications at the time you pick, even
  when Yomu is closed (they're systemd user timers named yomu-reminder-*).

HOW LINUX DIFFERS FROM MAC/PHONE
--------------------------------
- "Share" saves a file instead of opening a share sheet.
- Online cover search opens in your browser; paste the image address back.

FEEDBACK
--------
Please include your distro + desktop (e.g. "Fedora 41, KDE"), what you did,
and what happened. If something breaks, run `yomu` from a terminal and send
the output. Your library lives in ~/.local/share/com.ragoose.yomu
