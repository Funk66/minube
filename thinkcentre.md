# Notes

## Ubuntu

Extend the volume:

```bash
lvextend -r -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
```

## Tmux

Add to .bashrc:

```bash
if [[ $- == *i* ]] && [[ -n "$SSH_TTY" ]] && [[ -z "$TMUX" ]]; then
    exec tmux new-session -A -s main
fi
```
