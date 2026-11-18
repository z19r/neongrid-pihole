#!/bin/bash
# Self-check: install -> simulated "pihole -up" -> reapply -> restore,
# against a fake webroot (no root, no pihole-FTL needed).
set -eu
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export NG_TEST=1 WEBROOT="$tmp/www" WEBHOME=/admin/ STORE="$tmp/store"
export CRON_FILE="$tmp/cron" BIN_LINK="$tmp/bin" QUIET=1 PATH="$PATH"
t="$WEBROOT/admin/style/themes"
lp="$WEBROOT/admin/scripts/lua/footer.lp"
mkdir -p "$t" "$(dirname "$lp")"
echo "/* stock darker */" > "$t/default-darker.css"
echo "/* stock light */" > "$t/default-light.css"
src="<?=pihole.fileversion('scripts/js/footer.js')?>"
printf '%s\n' "<script src=\"$src\"></script>" > "$lp"
echo "<link href=\"style/themes/' ..theme.name.. '.css\">" \
  > "$WEBROOT/admin/scripts/lua/header.lp"
cp "$t/default-darker.css" "$tmp/stock.css"
cp "$t/default-light.css" "$tmp/stock-light.css"
cp "$lp" "$tmp/stock.lp"
fail() {
  echo "FAIL: $*"
  exit 1
}
ng() { bash "$here/neongrid.sh" "$@"; }

ng install
grep -q "NEON//GRID" "$t/default-darker.css" || fail "css not deployed"
grep -q "stock darker" "$t/default-darker.css" || fail "stock base dropped"
grep -q "NEON//GRID DAYDREAM" "$t/default-light.css" || fail "light css"
grep -q "stock light" "$t/default-light.css" || fail "light stock base"
grep -q "DAYDREAM" "$t/default-darker.css" && fail "light css in dark slot"
bash "$here/neongrid.sh" mode light > /dev/null || fail "mode light"
bash "$here/neongrid.sh" mode bogus 2> /dev/null && fail "mode accepts junk"
bash "$here/neongrid.sh" doctor > /dev/null || fail "doctor after install"
[ "$(grep -c neongrid-addons "$lp")" = 1 ] || fail "addon line != 1"
[ -f "$t/ng-sharetech.woff2" ] && [ -f "$CRON_FILE" ] || fail "fonts/cron"

ng install # idempotent
[ "$(grep -c neongrid-addons "$lp")" = 1 ] || fail "addon line duplicated"
n="$(grep -c 'NEON//GRID v' "$t/default-darker.css")"
[ "$n" = 1 ] || fail "css stacked"

cp "$tmp/stock.css" "$t/default-darker.css"
cp "$tmp/stock-light.css" "$t/default-light.css"
cp "$tmp/stock.lp" "$lp" # pihole -up
ng reapply
grep -q "NEON//GRID" "$t/default-darker.css" || fail "reapply css"
grep -q "DAYDREAM" "$t/default-light.css" || fail "reapply light css"
grep -q neongrid-addons "$lp" || fail "reapply addon"

ng restore
cmp -s "$t/default-darker.css" "$tmp/stock.css" || fail "restore css"
cmp -s "$t/default-light.css" "$tmp/stock-light.css" || fail "restore light"
cmp -s "$lp" "$tmp/stock.lp" || fail "restore footer"
[ ! -e "$CRON_FILE" ] && [ ! -e "$t/ng-sharetech.woff2" ] || fail "leftovers"
echo "PASS"
