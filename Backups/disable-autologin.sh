#!/usr/bin/env bash
rm /etc/systemd/system/getty@tty1.service.d/override.conf
systemctl daemon-reload
systemctl restart getty@tty1
systemctl disable disable-autologin.service