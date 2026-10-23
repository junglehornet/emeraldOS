alias hx="helix"
if status is-interactive
    # Commands to run in interactive sessions can go here
    starship init fish | source

    # Normalize the status passed to Starship after empty input, in both
    # prompts. Keep Starship's original status/pipeline capture otherwise.
    functions fish_prompt fish_right_prompt | string replace -- \
        '    set STARSHIP_CMD_STATUS $status' \
        '    set STARSHIP_CMD_STATUS $status
    if set -q __starship_empty_prompt
        set STARSHIP_CMD_STATUS 0
        set STARSHIP_CMD_PIPESTATUS 0
    end' | source

    # Fish retains CMD_DURATION after empty input. Only keep it for the
    # first prompt following an executed command.
    function __starship_mark_command_finished --on-event fish_postexec
        set -g __starship_fresh_duration 1
    end

    function __starship_clear_stale_duration --on-event fish_prompt
        if not set -q __starship_fresh_duration
            set -g CMD_DURATION 0
            set -e cmd_duration
            set -g __starship_empty_prompt 1
        else
            set -e __starship_empty_prompt
        end
        set -e __starship_fresh_duration
    end

    set -g fish_greeting ""
    fastfetch
end
