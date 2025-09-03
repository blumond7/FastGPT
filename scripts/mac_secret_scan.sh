#!/bin/bash

# Directory to store logs and PDFs
LOG_DIR="$HOME/security_scan_logs"
mkdir -p "$LOG_DIR"

DATE=$(date +"%Y-%m-%d-%H%M")
REPORT="$LOG_DIR/secret_scan_$DATE.txt"

EMAIL="changeme@example.com"

{
  echo "Secret scan started: $(date)";

  if command -v gitleaks >/dev/null; then
    echo "\nRunning gitleaks...";
    gitleaks detect -s "$HOME" --no-git -v 0 2>/dev/null;
  else
    echo "\ngitleaks not installed. Skipping gitleaks scan.";
  fi

  if command -v trufflehog >/dev/null; then
    echo "\nRunning trufflehog...";
    trufflehog filesystem "$HOME" --no-update 2>/dev/null;
  else
    echo "\ntrufflehog not installed. Skipping trufflehog scan.";
  fi

  echo "\nSearching for base64-encoded strings...";
  grep -RIl --exclude-dir={.git,$LOG_DIR} -E '[A-Za-z0-9+/]{20,}={0,2}' "$HOME" 2>/dev/null | while read -r file; do
    echo "File: $file";
    grep -Eo '[A-Za-z0-9+/]{20,}={0,2}' "$file" | head -n 5 | while read -r encoded; do
      echo "  Found: $encoded";
      decoded=$(echo "$encoded" | base64 -d 2>/dev/null | tr -d '\0')
      if [ -n "$decoded" ]; then
        echo "  Decoded: $decoded";
      fi
    done
  done

  echo "Secret scan finished: $(date)";
} > "$REPORT"

# Email the report if mail command is available
if command -v mail >/dev/null; then
  mail -s "Mac Secret Scan $DATE" "$EMAIL" < "$REPORT"
fi

chmod 600 "$REPORT" 2>/dev/null
