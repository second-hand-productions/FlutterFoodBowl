#!/usr/bin/env bash
#
# Privileged half of the COD deploy. Install this script to /usr/local/sbin/ as
# root-owned 0755 and run it from GitHub Actions through a single NOPASSWD
# sudoers rule:
#
#   mushbrain ALL=(ALL) NOPASSWD: /usr/local/sbin/deploy-cod-nginx.sh
#
# The repo copy is the source of truth, but it is not auto-installed by the
# workflow. Copy it into place manually whenever this file changes.
set -euo pipefail

WEB_SRC="${1:?usage: deploy-cod-nginx.sh <web_build_dir> <nginx_conf>}"
NGINX_CONF="${2:?usage: deploy-cod-nginx.sh <web_build_dir> <nginx_conf>}"

mkdir -p /var/www/cod
rsync -a --delete "${WEB_SRC%/}/" /var/www/cod/

# Install only this project's location fragment. The shared root vhost is
# infrastructure and is never rewritten by an app pipeline.
install -d -o root -g root -m 0755 /etc/nginx/apps.d
install -o root -g root -m 0644 "$NGINX_CONF" /etc/nginx/apps.d/foodbowl.conf

rm -f /etc/nginx/sites-enabled/cla
rm -f /etc/nginx/sites-enabled/cod
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/tailscale
rm -f /etc/nginx/sites-enabled/foodbowl

nginx -t
systemctl reload nginx
