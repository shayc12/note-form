#!/bin/bash
# Run on the existing application EC2 through Codex's SSH connection:
# sudo bash /opt/notes-app/scripts/update-app.sh <reviewed-main-commit>
set -euo pipefail
expected_commit=${1:?Provide the reviewed full GitHub main commit SHA}
case "$expected_commit" in
  *[!0-9a-f]*|'') echo "Use a lowercase full commit SHA" >&2; exit 1 ;;
esac
[ "${#expected_commit}" -eq 40 ] || { echo "Expected a 40-character commit SHA" >&2; exit 1; }
app_dir=/opt/notes-app
# Fail on source edits; do not overwrite work or force/reset the branch.
[ -z "$(sudo -u notesapp git -C "$app_dir" status --porcelain)" ] || {
  echo "Source tree has local changes; inspect before updating" >&2; exit 1;
}
[ "$(sudo -u notesapp git -C "$app_dir" branch --show-current)" = main ] || {
  echo "Expected main branch; inspect checkout" >&2; exit 1;
}
sudo -u notesapp env GIT_TERMINAL_PROMPT=0 git -C "$app_dir" -c credential.helper= pull --ff-only origin main
actual_commit=$(sudo -u notesapp git -C "$app_dir" rev-parse HEAD)
[ "$actual_commit" = "$expected_commit" ] || {
  echo "GitHub changed or target differs; review before restarting" >&2; exit 1;
}
sudo -u notesapp "$app_dir/.venv/bin/pip" install -r "$app_dir/requirements.txt"
systemctl restart notes-app
for attempt in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:8080/health; then
    printf '%s\n' "$actual_commit" > /var/log/notes-app-commit
    printf '\nUpdated application commit: %s\n' "$actual_commit"
    echo "Now verify SAME instance ID, SAME bucket and old/new notes from the training host."
    exit 0
  fi
  sleep 2
done
journalctl -u notes-app --no-pager -n 40
exit 1
