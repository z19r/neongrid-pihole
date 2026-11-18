#!/bin/bash
# ============================================================================
# neongrid.sh — NEON//GRID theme for Pi-hole v6 (installer and manager)
#
# Pi-hole v6 has a fixed theme list (built into FTL), so NEON//GRID takes two
# built-in slots: the stock file plus our CSS on top.
#   default-darker -> NEON//GRID (dark)
#   default-light  -> NEON//GRID DAYDREAM (light)
# "pihole -up" restores the stock files; a cron job re-applies the theme.
# Coexists with pihole-lizard-theme (which uses the high-contrast-dark slot).
#
#   sudo bash neongrid.sh install     install / update, select the theme
#   sudo neongrid mode dark|light     switch the web UI between the two
#   sudo neongrid reapply             put it back after a manual "pihole -up"
#   sudo neongrid doctor              check that everything is wired up
#   sudo neongrid status | version
#   sudo neongrid restore             stock look, cron and command removed
# ============================================================================
set -u

VERSION="1.1.0"
NAME="neongrid"
MARKER="NEON//GRID"
DARK_SLOT="default-darker"
LIGHT_SLOT="default-light"
SLOTS="$DARK_SLOT $LIGHT_SLOT"
STORE="${STORE:-/opt/neongrid}"
CRON_FILE="${CRON_FILE:-/etc/cron.d/neongrid}"
BIN_LINK="${BIN_LINK:-/usr/local/bin/neongrid}"
ADDON_JS="neongrid-addons.js"
FILES="neongrid.css neongrid-light.css $ADDON_JS ng-orbitron-700.woff2
  ng-orbitron-900.woff2 ng-sharetech.woff2"
SELF="$(readlink -f "$0")"
SRC_DIR="$(dirname "$SELF")"

say() { [ "${QUIET:-0}" = 1 ] || echo "$@"; }
die() {
  echo "ERROR: $*" >&2
  exit 1
}
need_root() {
  [ "${NG_TEST:-0}" = 1 ] || [ "$(id -u)" = 0 ] || die "run with sudo"
}
installed() { [ -f "$STORE/active" ]; }
is_ours() { [ -f "$1" ] && grep -q "$MARKER" "$1"; }
ftl() { command -v pihole-FTL > /dev/null 2>&1 && pihole-FTL "$@"; }
ftl_theme() { ftl --config webserver.interface.theme 2> /dev/null; }

theme_dir() {
  local root home
  root="${WEBROOT:-$(ftl --config webserver.paths.webroot 2> /dev/null)}"
  home="${WEBHOME:-$(ftl --config webserver.paths.webhome 2> /dev/null)}"
  root="${root:-/var/www/html}"
  home="${home:-/admin/}"
  echo "${root%/}/${home#/}style/themes" | sed 's#//*#/#g'
}
footer_lp() { echo "$(dirname "$(dirname "$1")")/scripts/lua/footer.lp"; }
fix_perms() {
  chown --reference="$(dirname "$1")" "$1" 2> /dev/null
  chmod 644 "$1"
}

# stock slot file + our CSS, so unstyled pages still get the stock look
build_css() {
  local slot="$1" out="$STORE/.$1.css"
  {
    cat "$STORE/$slot.css.orig"
    printf '\n/* %s v%s — appended by neongrid.sh */\n' "$MARKER" "$VERSION"
    cat "$STORE/neongrid.css"
    if [ "$slot" = "$LIGHT_SLOT" ]; then cat "$STORE/neongrid-light.css"; fi
  } > "$out.tmp" && mv -f "$out.tmp" "$out"
  echo "$out"
}

slot_current() {
  is_ours "$1/$2.css" && cmp -s "$(build_css "$2")" "$1/$2.css"
}

addon_line() {
  local src="<?=pihole.fileversion('style/themes/$ADDON_JS')?>"
  echo "<script src=\"$src\"></script>"
}

deploy() {
  local tdir="$1" f lp slot
  [ -d "$tdir" ] || die "themes directory not found: $tdir (Pi-hole v6?)"
  for slot in $SLOTS; do
    # back up the stock file — only if the slot does not hold our theme
    if [ -f "$tdir/$slot.css" ] && ! is_ours "$tdir/$slot.css"; then
      cp -f "$tdir/$slot.css" "$STORE/$slot.css.orig"
    fi
    [ -f "$STORE/$slot.css.orig" ] || die "no stock $slot.css to build on"
    cp -f "$(build_css "$slot")" "$tdir/$slot.css"
    fix_perms "$tdir/$slot.css"
  done
  for f in "$STORE"/ng-*.woff2 "$STORE/$ADDON_JS"; do
    cp -f "$f" "$tdir/" && fix_perms "$tdir/$(basename "$f")"
  done
  lp="$(footer_lp "$tdir")"
  if [ ! -f "$lp" ]; then
    say "  [i] $lp not found — add-ons skipped"
  elif ! grep -q "$ADDON_JS" "$lp"; then
    if grep -q "scripts/js/footer.js" "$lp"; then
      sed -i "/scripts\/js\/footer.js/a $(addon_line)" "$lp"
    else
      say "  [i] unknown footer.lp layout — add-ons skipped"
    fi
  fi
}

undeploy_addon() {
  local tdir="$1" lp
  lp="$(footer_lp "$tdir")"
  [ -f "$lp" ] && sed -i "/$ADDON_JS/d" "$lp"
  rm -f "$tdir/$ADDON_JS" "$tdir"/ng-*.woff2
}

write_cron() {
  cat > "$CRON_FILE" << EOF
# NEON//GRID: 'pihole -up' (Sunday cron) restores stock files - put it back
30 3 * * 0 root QUIET=1 $STORE/neongrid.sh reapply
@reboot root sleep 120 && QUIET=1 $STORE/neongrid.sh reapply
EOF
  chmod 644 "$CRON_FILE"
}

select_slot() {
  if ftl --config webserver.interface.theme "$1" > /dev/null 2>&1; then
    say "  [✓] theme selected (webserver.interface.theme = $1)"
  else
    say "  [i] select it: Settings -> Web interface / API -> Theme -> $1"
  fi
}

cmd_install() {
  need_root
  local f tdir
  tdir="$(theme_dir)"
  mkdir -p "$STORE"
  if [ "$SRC_DIR" != "$STORE" ]; then
    for f in $FILES; do
      [ -f "$SRC_DIR/$f" ] || die "missing $f (must sit next to the script)"
      cp -f "$SRC_DIR/$f" "$STORE/"
    done
    cp -f "$SELF" "$STORE/neongrid.sh"
  fi
  chmod 755 "$STORE/neongrid.sh"
  ln -sf "$STORE/neongrid.sh" "$BIN_LINK"
  echo "$VERSION" > "$STORE/active"
  rm -f "$STORE/.active.css" # v1.0 build file
  deploy "$tdir"
  say "  [✓] NEON//GRID jacked into $DARK_SLOT (dark) + $LIGHT_SLOT (light)"
  write_cron
  say "  [✓] cron: $CRON_FILE"
  # keep the user's light/dark choice on reinstall
  case " $SLOTS " in
    *" $(ftl_theme) "*) say "  [✓] theme stays on $(ftl_theme)" ;;
    *) select_slot "$DARK_SLOT" ;;
  esac
  say ""
  say "  >> neongrid $VERSION online. Ctrl+F5 the admin page. Try ↑↑↓↓←→←→BA."
  say "  >> light mode: sudo neongrid mode light"
}

cmd_mode() {
  need_root
  installed || die "not installed — run 'install' first"
  case "${1:-}" in
    dark) select_slot "$DARK_SLOT" ;;
    light) select_slot "$LIGHT_SLOT" ;;
    *) die "usage: neongrid mode dark|light" ;;
  esac
}

cmd_reapply() {
  need_root
  installed || die "not installed — run 'install' first"
  local tdir slot stale=0
  tdir="$(theme_dir)"
  for slot in $SLOTS; do
    slot_current "$tdir" "$slot" || stale=1
  done
  if [ "$stale" = 0 ] && grep -qs "$ADDON_JS" "$(footer_lp "$tdir")"; then
    say "  [✓] already in place — nothing to do"
    return 0
  fi
  deploy "$tdir"
  logger -t neongrid "theme re-applied in $tdir" 2> /dev/null
  say "  [✓] NEON//GRID re-applied"
}

cmd_restore() {
  need_root
  local tdir slot
  tdir="$(theme_dir)"
  for slot in $SLOTS; do
    if is_ours "$tdir/$slot.css" && [ -f "$STORE/$slot.css.orig" ]; then
      cp -f "$STORE/$slot.css.orig" "$tdir/$slot.css"
      fix_perms "$tdir/$slot.css"
      say "  [✓] stock $slot.css restored"
    fi
    rm -f "$STORE/.$slot.css"
  done
  undeploy_addon "$tdir"
  rm -f "$CRON_FILE" "$BIN_LINK" "$STORE/active"
  case " $SLOTS " in
    *" $(ftl_theme) "*)
      ftl --config webserver.interface.theme default-auto > /dev/null 2>&1 &&
        say "  [✓] theme set to default-auto"
      ;;
  esac
  say "  [i] package files remain in $STORE (sudo rm -rf $STORE)"
}

cmd_status() {
  local tdir slot
  tdir="$(theme_dir)"
  echo "neongrid  : $VERSION ($(installed && echo installed || echo absent))"
  for slot in $SLOTS; do
    echo "slot      : $tdir/$slot.css ($(is_ours "$tdir/$slot.css" &&
      echo NEON//GRID || echo stock))"
  done
  echo "add-on    : $(grep -qs "$ADDON_JS" "$(footer_lp "$tdir")" &&
    echo attached || echo detached)"
  echo "cron      : $([ -f "$CRON_FILE" ] && echo "$CRON_FILE" || echo none)"
  echo "FTL theme : $(ftl_theme)"
}

cmd_doctor() {
  local tdir lp adir slot fails=0
  ok() { echo "  [OK]   $*"; }
  fail() {
    echo "  [FAIL] $*"
    fails=$((fails + 1))
  }
  tdir="$(theme_dir)"
  lp="$(footer_lp "$tdir")"
  adir="$(dirname "$(dirname "$tdir")")"
  echo "neongrid $VERSION — diagnostics"
  [ -d "$tdir" ] && ok "themes dir: $tdir" || fail "themes dir missing: $tdir"
  installed && ok "installed in $STORE" || fail "not installed — run install"
  for slot in $SLOTS; do
    if ! is_ours "$tdir/$slot.css"; then
      fail "slot $slot is stock (after an update?) — run: sudo neongrid reapply"
    elif installed && slot_current "$tdir" "$slot"; then
      ok "slot $slot holds current NEON//GRID"
    else
      fail "slot $slot is stale — run: sudo neongrid reapply"
    fi
  done
  [ -f "$tdir/ng-orbitron-900.woff2" ] && ok "fonts deployed" ||
    fail "fonts missing — run: sudo neongrid reapply"
  grep -qs "$ADDON_JS" "$lp" && [ -f "$tdir/$ADDON_JS" ] &&
    ok "add-on attached (footer.lp)" || fail "add-on detached — run reapply"
  grep -qs "style/themes/' ..theme.name" "$adir/scripts/lua/header.lp" &&
    ok "header.lp loads themes from the slot" ||
    fail "header.lp changed how it loads themes"
  case " $SLOTS " in
    *" $(ftl_theme) "*) ok "FTL theme = $(ftl_theme)" ;;
    *) echo "  [WARN] FTL theme is $(ftl_theme) — run: neongrid mode dark" ;;
  esac
  [ -f "$CRON_FILE" ] && ok "cron: $CRON_FILE" || fail "no cron job"
  echo "Result: errors=$fails"
  [ "$fails" -eq 0 ]
}

case "${1:-}" in
  install) cmd_install ;;
  mode) cmd_mode "${2:-}" ;;
  reapply) cmd_reapply ;;
  restore) cmd_restore ;;
  status) cmd_status ;;
  doctor) cmd_doctor ;;
  version | --version | -v) echo "$NAME $VERSION" ;;
  *)
    echo "usage: $0 install|mode dark|light|reapply|doctor|status|restore"
    exit 2
    ;;
esac
