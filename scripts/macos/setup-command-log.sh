#!/bin/zsh
set -euo pipefail

CONFIG_DIR="${HOME}/.config/fastgpt-terminal"
LOG_FILE="${CONFIG_DIR}/command-log-$(hostname).tsv"
ZSHRC="${HOME}/.zshrc"
BLOCK_START="# >>> fastgpt-command-log >>>"
BLOCK_END="# <<< fastgpt-command-log <<<"

mkdir -p "${CONFIG_DIR}"
touch "${LOG_FILE}"

if [ ! -f "${ZSHRC}" ]; then
  touch "${ZSHRC}"
fi

if grep -Fq "${BLOCK_START}" "${ZSHRC}"; then
  echo "[fastgpt-command-log] Configuration block already present in ${ZSHRC}." >&2
  echo "[fastgpt-command-log] Commands are being logged to ${LOG_FILE}." >&2
  exit 0
fi

cat >> "${ZSHRC}" <<'BLOCK'
# >>> fastgpt-command-log >>>
# Configure zsh history so every command is saved and easy to search later.
export HISTFILE="${HOME}/.config/fastgpt-terminal/zsh_history"
export HISTSIZE=500000
export SAVEHIST=500000
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS

FASTGPT_COMMAND_LOG_DIR="${HOME}/.config/fastgpt-terminal"
FASTGPT_COMMAND_LOG_FILE="${FASTGPT_COMMAND_LOG_DIR}/command-log-$(hostname).tsv"
mkdir -p "${FASTGPT_COMMAND_LOG_DIR}"
touch "${FASTGPT_COMMAND_LOG_FILE}"

function _fastgpt_log_preexec() {
  typeset -g FASTGPT_LAST_COMMAND="$1"
  typeset -g FASTGPT_LAST_DIRECTORY="$PWD"
  printf '%s\tSTART\t%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$PWD" "$1" >> "${FASTGPT_COMMAND_LOG_FILE}"
}

function _fastgpt_log_precmd() {
  local status=$?
  if [[ -n "${FASTGPT_LAST_COMMAND-}" ]]; then
    printf '%s\tEND\t%s\t%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "${FASTGPT_LAST_DIRECTORY}" "$status" "${FASTGPT_LAST_COMMAND}" >> "${FASTGPT_COMMAND_LOG_FILE}"
    unset FASTGPT_LAST_COMMAND FASTGPT_LAST_DIRECTORY
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _fastgpt_log_preexec
add-zsh-hook precmd _fastgpt_log_precmd
# <<< fastgpt-command-log <<<
BLOCK

echo "[fastgpt-command-log] Added persistent command logging to ${ZSHRC}." >&2
echo "[fastgpt-command-log] Commands will be logged to ${LOG_FILE}." >&2
