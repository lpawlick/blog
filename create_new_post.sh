#!/usr/bin/env bash

# Renders a text based list of options that can be selected by the
# user using up, down and enter keys and returns the chosen option.
#
#   Arguments   : list of options, maximum of 256
#                 "opt1" "opt2" ...
#   Return value: selected index (0 for opt1, 1 for opt2 ...)
function select_option {

    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()  { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
    print_option()     { printf "   $1 "; }
    print_selected()   { printf "  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    key_input()        { read -s -n3 key 2>/dev/null >&2
                        if [[ $key = $ESC[A ]]; then echo up;    fi
                        if [[ $key = $ESC[B ]]; then echo down;  fi
                        if [[ $key = ""     ]]; then echo enter; fi; }

    # initially print empty new lines (scroll down if at bottom of screen)
    for opt; do printf "\n"; done

    # determine current screen position for overwriting the options
    local lastrow=`get_cursor_row`
    local startrow=$(($lastrow - $#))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local selected=0
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for opt; do
            cursor_to $(($startrow + $idx))
            if [ $idx -eq $selected ]; then
                print_selected "$opt"
            else
                print_option "$opt"
            fi
            ((idx++))
        done

        # user key control
        case `key_input` in
            enter) break;;
            up)    ((selected--));
                if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi;;
            down)  ((selected++));
                if [ $selected -ge $# ]; then selected=0; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    return $selected
}

# Easy selection for case
function select_opt 
{
    select_option "$@" 1>&2
    local result=$?
    echo $result
    return $result
}


# Functions for entering metadata
function get_post_name
{
    printf "\033c"
    echo "Please enter a post name:"
    echo 

    read postname
}

function get_post_tags
{
    printf "\033c"
    echo "Please enter the tags of the post:"
    echo 

    read posttags
}

function get_post_category
{
    printf "\033c"
    echo "Select one option using up/down keys and enter to confirm:"
    echo

    options=("Programming, Tutorial" "Programming, Opinion" "Books")
    select_option "${options[@]}"
    choice=$?
    postcategories=${options[$choice]}
}

function get_basic_post_metadata
{
    get_post_name
    get_post_tags
    get_post_category
}

# Write basic metadata
function set_draft_post_metadata
{
    sed -i "s/{tags}/$posttags/g" ./drafts/$postname.rst
    sed -i "s/{categories}/$postcategories/g" ./drafts/$postname.rst
}

printf "\033c" # Clear screen
echo "Create a new post or release a draft?"
echo 

case `select_opt "New Post" "Release draft"` in
    0) 
        printf "\033c"
        echo "Select template:"
        echo 

        case `select_opt "Empty Post" "Post with text" "Post with images" "Post with everything"` in
            0) 
                get_basic_post_metadata
                cp ./templates/empty_post.rst ./drafts/$postname.rst
                set_draft_post_metadata
                echo "New draft with the name $postname created"
                ;;
            1) 
                get_basic_post_metadata
                cp ./templates/posts_with_text.rst ./drafts/$postname.rst
                set_draft_post_metadata
                echo "New draft with the name $postname created"
                ;;
            2) 
                get_basic_post_metadata
                cp ./templates/post_with_images.rst ./drafts/$postname.rst
                set_draft_post_metadata
                echo "New draft with the name $postname created"
                ;;
            3) 
                get_basic_post_metadata
                cp ./templates/posts_with_everything.rst ./drafts/$postname.rst
                set_draft_post_metadata
                echo "New draft with the name $postname created"
                ;;
        esac
    ;;
    1) 
    printf "\033c"
    echo "Select the draft to release"
    echo

    options=($(ls ./drafts | sed -e 's/\.rst$//'))
    select_option "${options[@]}"
    choice=$?
    file_to_release=${options[$choice]}
    current_date=$(date '+%d.%m.%Y')
    sed -i "s/{date}/$current_date/g" ./drafts/$file_to_release.rst
    mv ./drafts/$file_to_release.rst ./posts/$file_to_release.rst
    echo "Moved draft $file_to_release to posts"
    ;;
esac
