# completion/ye.bash
_ye_complete() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    local scripts_dir="${SCRIPTS_DIR:-$HOME/barebash/scripts}"
    local opts=()

    # List all available .sh scripts
    for f in "$scripts_dir"/*.sh; do
        [[ -e "$f" ]] && opts+=("$(basename "${f%.sh}")")
    done

    # Completion rules
    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "${opts[*]}" -- "$cur") )
    elif [[ $COMP_CWORD -eq 2 && " ${opts[*]} " =~ " ${prev} " ]]; then
        COMPREPLY=( $(compgen -W "edit" -- "$cur") )
    fi
}
complete -F _ye_complete ye