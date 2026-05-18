# ~/.bashrc

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# History control
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000

# Aliases for installed tools
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons'
    alias ll='eza -l --icons'
    alias la='eza -la --icons'
    alias lt='eza --tree --icons'
fi

if command -v bat >/dev/null 2>&1; then
    alias cat='bat -p'
fi

if command -v rg >/dev/null 2>&1; then
    alias grep='rg'
fi

if command -v fd >/dev/null 2>&1; then
    alias find='fd'
fi

# Initialize prompts and integrations
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --bash)"
fi
