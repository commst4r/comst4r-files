if status is-interactive
    # Commands to run in interactive sessions can go here
    # Start X at login
    if status is-login
	    if test -z "$DISPLAY" -a "$XDG_VTNR" = 1
		    exec startx -- -keeptty
	    end
    end
    alias nv=vim 
    alias ll='lsd -lA' 
    alias build_suckless='rm -rf config.h; sudo make clean install' 
    zoxide init fish | source
end
