function __fzf_tab_complete --description 'Pick ambiguous Fish completions in a small fzf window'
    set -l candidates (complete --escape --color=never -C (commandline --cut-at-cursor))

    # Let Fish handle spacing and other native behavior for a unique match.
    if test (count $candidates) -lt 2; or not command -q fzf
        commandline --function complete
        return
    end

    # Seed the search with the filename fragment, excluding its directory.
    set -l token (string unescape -- (commandline --current-token --cut-at-cursor))
    set -l query ''
    if set -q token[1]
        set query (string replace --regex '^.*/' '' -- "$token")
    end

    # Keep this picker compact even when global fzf options enable a preview
    # or a full-screen/tmux layout. Descriptions remain visible after the tab.
    set -l selected (printf '%s\n' $candidates | command env FZF_DEFAULT_OPTS= FZF_DEFAULT_OPTS_FILE= fzf \
        --height=12 --layout=reverse --border=rounded --info=inline \
        --exact --delimiter=\t --nth=1 \
        --no-multi --cycle --prompt='Complete > ' --query="$query" --bind=tab:down,shift-tab:up)

    if test (count $selected) -gt 0
        set -l completion (string split --max 1 \t -- $selected)[1]
        commandline --current-token --replace -- $completion
    end
    commandline --function repaint
end
