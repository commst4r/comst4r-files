if status is-interactive
    # Commands to run in interactive sessions can go here
    # Start X at login
    if status is-login
	    if test -z "$DISPLAY" -a "$XDG_VTNR" = 1
		    exec startx -- -keeptty
	    end
    end
    alias nv=nvim 
    alias c=clear 
    alias ls='lsd' 
    alias ll='lsd -lA' 
    alias lt='lsd --tree' 
    alias t='tmux' 
    alias build_suckless='rm -rf config.h; sudo make clean install' 
    zoxide init fish | source
    fish_vi_key_bindings
    set -Ux MANPAGER "sh -c 'col -bx | bat -l man -p'"

end    # Commands to run in interactive sessions can go here
