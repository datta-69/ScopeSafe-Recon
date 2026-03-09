#!/usr/bin/env bash

show_banner() {
    clear
    cat << 'EOF'
        )    )    )                   )          (     
     ( /( ( /( ( /(           (    ( /(   (      )\ )  
 (   )\()))\()))\())          )\   )\())( )\ (  (()/(  
 )\ ((_)\((_)\((_)\   ___   (((_) ((_)\ )((_))\  /(_)) 
((_) _((_) ((_)_((_) |___|  )\_____ ((_|(_)_((_)(_))   
| __| \| |/ _ \ \/ /       ((/ __\ \ / /| _ ) __| _ \  
| _|| .` | (_) >  <         | (__ \ V / | _ \ _||   /  
|___|_|\_|\___/_/\_\         \___| |_|  |___/___|_|_\  
                                                       

                                                    
            E N O X - C Y B E R
        P E N T E S T   T O O L K I T
EOF

    echo
    color_echo "$BRIGHT_MAGENTA" "[ Professional Bash Pentest Toolkit ]"
    color_echo "$BRIGHT_YELLOW" "For educational and authorized penetration testing only."
    hr
}

show_loading() {
    local msg="$1"
    local delay="${2:-0.05}"
    local dots=("." ".." "..." "....")
    for i in {1..12}; do
        printf "\r%s%s" "$msg" "${dots[$((i % 4))]}"
        sleep "$delay"
    done
    printf "\r%-65s\n" ""
}
