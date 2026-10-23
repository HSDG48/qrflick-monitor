# qrflick-monitor

External uptime checks for [QRflick](https://qrflick.com) QR redirects, run by GitHub Actions every 5 minutes.

- `checks.conf`: what is checked (status, exact `Location` or page text, time limit).
- `check.sh`: runs the checks with curl (`bash check.sh` works locally too).
- `alert.sh`: opens one `monitor-alert` issue after a check fails 2 runs in a row; closes it on recovery.

Alert drill: Actions → Monitor → Run workflow, `simulate_failure` = `link-external`, run it twice.

Requests identify as `QRflickUptimeBot/1.0`, and short links are checked with `HEAD`, so they never count as scans.
Full notes live in the QRflick app repo: `docs/REDIRECT-MONITORING.md`.
