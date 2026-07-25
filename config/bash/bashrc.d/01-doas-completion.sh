# Reuse bash-completion's generic command completion for doas
declare -F _command >/dev/null && complete -F _command doas
