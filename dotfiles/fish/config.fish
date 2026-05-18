# ~/.config/fish/config.fish

# Disable default greeting
set fish_greeting ""

if status is-interactive
    # Environment variables
    set -gx EDITOR "nano"
    
    # Aliases mapped to modern rust tools
    if command -v eza >/dev/null
        alias ls 'eza --icons'
        alias ll 'eza -l --icons'
        alias la 'eza -la --icons'
        alias lt 'eza --tree --icons'
    end

    if command -v bat >/dev/null
        alias cat 'bat -p'
    end

    if command -v rg >/dev/null
        alias grep rg
    end
    
    if command -v fd >/dev/null
        alias find fd
    end

    # Initialize prompts and integrations
    if command -v starship >/dev/null
        starship init fish | source
    end

    if command -v zoxide >/dev/null
        zoxide init fish | source
    end
    
    # FZF usually provides its own bindings out of the box in fish, 
    # but some newer versions support native fish initialization:
    if command -v fzf >/dev/null
        fzf --fish | source 2>/dev/null || true
    end
end
