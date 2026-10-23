#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias hx="helix"
export PATH="$PATH:/home/junglehornet/.local/bin"
# PS1='[\u@\h \W]\$ '
exec fish
