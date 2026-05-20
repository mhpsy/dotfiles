#!/usr/bin/env bash
# Dump HH:mm in several timezones for ClockCard. One key=value per line.
# TZ env var is the canonical way to get tz-aware time across DST.
echo "california=$(TZ='America/Los_Angeles' date '+%H:%M')"
echo "toronto=$(TZ='America/Toronto'        date '+%H:%M')"
echo "tokyo=$(TZ='Asia/Tokyo'               date '+%H:%M')"
echo "seoul=$(TZ='Asia/Seoul'               date '+%H:%M')"
