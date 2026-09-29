# Retired Midship configuration

The original server at 5.78.184.57 was instructed to power off on 2026-09-29.
This directory preserves its configuration and is deliberately not imported by
`den/default.nix`. The active replacement is `hosts/midship` at 40.160.139.91,
formerly named Ascension.

The retired server still has its old configuration on disk. Booting it can
restart stale application writers and bots. Do not boot or redeploy it without
first arranging an isolated recovery or retirement procedure.
