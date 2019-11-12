#!/bin/sh
systemctl stop nginx
systemctl disable nginx
rm -f /etc/systemd/system/nginx.service
rm -rf /etc/nginx
rm -f /usr/local/bin/nginx
