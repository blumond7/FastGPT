#!/bin/bash

# Directory to store logs and PDFs
LOG_DIR="$HOME/security_scan_logs"
mkdir -p "$LOG_DIR"

DATE=$(date +"%Y-%m-%d-%H%M")
REPORT="$LOG_DIR/scan_$DATE.txt"
PDF_REPORT="$LOG_DIR/scan_$DATE.pdf"

EMAIL="changeme@example.com"

{
  echo "Security scan started: $(date)";

  echo "\nFinding hidden files...";
  sudo find / -name ".*" -type f 2>/dev/null;

  echo "\nListing listening network processes...";
  lsof -i | grep -i "LISTEN";

  if command -v clamscan >/dev/null; then
    echo "\nRunning ClamAV scan...";
    clamscan -r / --quiet;
  else
    echo "\nClamAV not installed. Skipping antivirus scan.";
  fi

  if [ -x "$(dirname "$0")/mac_secret_scan.sh" ]; then
    echo "\nRunning secret scan...";
    "$(dirname "$0")/mac_secret_scan.sh" >> "$REPORT"
  else
    echo "\nmac_secret_scan.sh not found. Skipping secret scan.";
  fi

  echo "Security scan finished: $(date)";
} > "$REPORT"

# Convert report to PDF using pandoc or enscript+ps2pdf
if command -v pandoc >/dev/null; then
  pandoc "$REPORT" -o "$PDF_REPORT"
elif command -v enscript >/dev/null && command -v ps2pdf >/dev/null; then
  enscript "$REPORT" -o - | ps2pdf - "$PDF_REPORT"
else
  echo "pandoc or enscript+ps2pdf not found. PDF report not created." >> "$REPORT"
  PDF_REPORT=""
fi

# Email the report if mail command is available
if [ -n "$PDF_REPORT" ] && command -v mail >/dev/null; then
  mail -s "Mac Security Scan $DATE" -a "$PDF_REPORT" "$EMAIL" < "$REPORT"
fi

chmod 600 "$REPORT" "$PDF_REPORT" 2>/dev/null
