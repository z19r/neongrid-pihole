# NEON//GRID Pi-hole theme
host := "root@z19r-networking"
prettier := "npx --yes prettier@3"
shfmt := "go run mvdan.cc/sh/v3/cmd/shfmt@v3.10.0 -i 2 -ci -sr"

default:
    @just --list

# format everything (80 cols)
fmt:
    {{prettier}} --write "theme/*.css" "theme/*.js" README.md
    {{shfmt}} -w theme/*.sh theme/test/*.sh

# fail if anything is unformatted or over 80 columns
fmt-check:
    {{prettier}} --check "theme/*.css" "theme/*.js" README.md
    {{shfmt}} -d theme/*.sh theme/test/*.sh
    ! awk 'length > 80 { print FILENAME":"FNR; f=1 } END { exit !f }' \
        theme/*.css theme/*.js theme/*.sh theme/test/*.sh

# installer self-test against a fake webroot
test:
    bash theme/test/neongrid_test.sh

# copy to the Pi and install
deploy: test
    ssh {{host}} 'mkdir -p /root/neongrid'
    scp theme/neongrid.sh theme/neongrid*.css theme/neongrid-addons.js \
        theme/*.woff2 {{host}}:/root/neongrid/
    ssh {{host}} 'bash /root/neongrid/neongrid.sh install && neongrid doctor'

doctor:
    ssh {{host}} neongrid doctor

restore:
    ssh {{host}} neongrid restore
