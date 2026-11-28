#!/usr/bin/env bash
# Builds Yomu for Linux and packages it for testers:
#   dist/yomu_<version>_amd64.deb         Ubuntu, Debian, Mint, Pop!_OS
#   dist/yomu-<version>-linux-x64.tar.gz  any other distro (has install.sh)
#
# Usage: linux/packaging/package.sh   (FLUTTER=/path/to/flutter to override)
set -euo pipefail

cd "$(dirname "$0")/../.."
FLUTTER="${FLUTTER:-flutter}"
APP_ID=com.ragoose.yomu
VERSION=$(sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml)
PKG=linux/packaging
BUNDLE=build/linux/x64/release/bundle
ICONS=macos/Runner/Assets.xcassets/AppIcon.appiconset
OUT=dist

"$FLUTTER" build linux --release
rm -rf "$OUT" && mkdir -p "$OUT"

# Lays out the desktop integration files under $1 (a usr/ or ~/.local prefix).
install_desktop_files() {
  local share="$1/share"
  install -Dm644 "$PKG/$APP_ID.desktop" "$share/applications/$APP_ID.desktop"
  install -Dm644 "$PKG/$APP_ID.xml" "$share/mime/packages/$APP_ID.xml"
  for size in 16 32 64 128 256 512; do
    install -Dm644 "$ICONS/app_icon_$size.png" \
      "$share/icons/hicolor/${size}x${size}/apps/$APP_ID.png"
  done
}

# --- .deb -------------------------------------------------------------------
DEB="$OUT/deb"
mkdir -p "$DEB/opt/yomu" "$DEB/usr/bin" "$DEB/DEBIAN"
cp -r "$BUNDLE"/. "$DEB/opt/yomu/"
ln -s /opt/yomu/yomu "$DEB/usr/bin/yomu"
install_desktop_files "$DEB/usr"
cat > "$DEB/DEBIAN/control" <<EOF
Package: yomu
Version: $VERSION
Architecture: amd64
Maintainer: RaGoose
Section: text
Priority: optional
Installed-Size: $(du -sk "$DEB" | cut -f1)
Depends: libgtk-3-0t64 | libgtk-3-0, libmpv2 | libmpv1, ffmpeg, pulseaudio-utils, libnotify-bin, ca-certificates, libgles2, libegl1
Recommends: xdg-desktop-portal-gnome | xdg-desktop-portal-gtk | xdg-desktop-portal-kde, fonts-noto-cjk
Description: Read EPUBs and PDFs and build a reading habit
 Yomu is a reading companion: highlights, notes and voice notes,
 shareable annotated books, reading stats, streaks and quests.
 Voice notes play through libmpv and record through parecord and ffmpeg.
EOF
chmod -R u=rwX,go=rX "$DEB"
dpkg-deb --root-owner-group --build "$DEB" "$OUT/yomu_${VERSION}_amd64.deb"
rm -rf "$DEB"

# --- .tar.gz ----------------------------------------------------------------
NAME="yomu-$VERSION-linux-x64"
TAR="$OUT/$NAME"
mkdir -p "$TAR/app" "$TAR/desktop"
cp -r "$BUNDLE"/. "$TAR/app/"
install_desktop_files "$TAR/desktop"
cat > "$TAR/install.sh" <<'EOF'
#!/usr/bin/env bash
# Installs Yomu for the current user (no root needed): the app goes to
# ~/.local/opt/yomu, the `yomu` command to ~/.local/bin, and Yomu shows up
# in the app menu and in "Open With" for EPUB, PDF and .yomu files.
#
# Not ~/.local/share/yomu: the app would take a folder there named after
# itself as its data folder, so reinstalling would wipe the library. The
# library lives in ~/.local/share/com.ragoose.yomu and is never touched here.
set -euo pipefail
cd "$(dirname "$0")"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
APP="$HOME/.local/opt/yomu"
rm -rf "$APP" && mkdir -p "$APP" "$HOME/.local/bin"
cp -r app/. "$APP/"
ln -sf "$APP/yomu" "$HOME/.local/bin/yomu"
cp -r desktop/share/. "$DATA/"
sed -i "s|^Exec=yomu|Exec=$APP/yomu|" "$DATA/applications/com.ragoose.yomu.desktop"
update-mime-database "$DATA/mime" 2>/dev/null || true
update-desktop-database "$DATA/applications" 2>/dev/null || true
gtk-update-icon-cache -f -t "$DATA/icons/hicolor" 2>/dev/null || true
echo "Yomu installed. Open it from your app menu, or run: yomu"
for tool in parecord ffmpeg; do
  command -v "$tool" >/dev/null || echo "Note: install '$tool' to record voice notes."
done
command -v notify-send >/dev/null ||
  echo "Note: install notify-send (libnotify) to get reading reminders while Yomu is closed."
# grep -c reads all of ldconfig's output: -q would quit early, and
# pipefail would then count ldconfig's broken pipe as "not installed".
ldconfig -p 2>/dev/null | grep -c 'libmpv\.so' >/dev/null ||
  echo "Note: install libmpv (mpv) to play voice notes and audiobooks."
EOF
chmod +x "$TAR/install.sh"
cp "$PKG/README-testers.txt" "$TAR/README.txt"
chmod -R u=rwX,go=rX "$TAR"
tar -C "$OUT" --owner=0 --group=0 --numeric-owner -czf "$OUT/$NAME.tar.gz" "$NAME"
rm -rf "$TAR"

ls -lh "$OUT"
