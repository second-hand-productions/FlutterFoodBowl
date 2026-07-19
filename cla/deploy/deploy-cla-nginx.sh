#!/usr/bin/env bash
#
# Privileged half of the CLA deploy. Installed to /usr/local/sbin/ as root-owned
# 0755 and run by the GitHub Actions runner via a single NOPASSWD sudoers rule:
#
#   mushbrain ALL=(ALL) NOPASSWD: /usr/local/sbin/deploy-cla-nginx.sh
#
# The runner can therefore perform exactly this deploy and nothing else with root.
# This file in the repo is the source of truth for the script's contents, but it
# is NOT auto-installed by the workflow (that would defeat the trust boundary) --
# copy it into place manually whenever it changes. See cla/deploy/README.md.
#
# Args are treated strictly as file paths (quoted, no eval), so a hostile value
# can at worst fail or install a bad nginx config -- it cannot run arbitrary
# root commands.
set -euo pipefail

WEB_SRC="${1:?usage: deploy-cla-nginx.sh <web_build_dir> <nginx_conf>}"
NGINX_CONF="${2:?usage: deploy-cla-nginx.sh <web_build_dir> <nginx_conf>}"

# Publish the Flutter web build.
mkdir -p /var/www/cla
rsync -a --delete "${WEB_SRC%/}/" /var/www/cla/

# Install only this project's location fragment. The shared root vhost is
# infrastructure and is never rewritten by an app pipeline.
install -d -o root -g root -m 0755 /etc/nginx/apps.d
install -o root -g root -m 0644 "$NGINX_CONF" /etc/nginx/apps.d/foodbowl.conf

# Remove legacy per-app/shared vhosts so they cannot conflict on server_name.
rm -f /etc/nginx/sites-enabled/cla
rm -f /etc/nginx/sites-enabled/cod
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/tailscale
rm -f /etc/nginx/sites-enabled/foodbowl

# Validate before reloading. On failure, set -e aborts here and the running
# nginx keeps its current in-memory config untouched.
nginx -t
systemctl reload nginx
