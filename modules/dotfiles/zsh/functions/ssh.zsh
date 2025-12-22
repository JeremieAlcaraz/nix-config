
# ~/.config/zsh/modules/ssh.zsh (par ex.)
ssh-who() {
  if [[ -z "$1" ]]; then
    print -u2 "usage: ssh-who <host> [host2 ...]"
    return 2
  fi
  for h in "$@"; do
    print -- "== $h =="
    ssh -G -- "$h" 2>/dev/null | grep -Ei '^(identity(agent|file|iesonly))\b'
    print
  done
}
