# SPDX-FileCopyrightText: 2023 Klarälvdalens Datakonsult AB, a KDAB Group company <info@kdab.com>
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only

#!/bin/sh

if [ "$#" -ne 3 ] ; then
    echo "Usage: compare_captures.sh <PR_NUMBER> <reference_capture_dir> <current_capture_dir>"
    exit 1
fi

PR_NUMBER=$1
REFERENCE_CAPTURES_DIR=$2
PR_CAPTURES_DIR=$3
DIFF_DIR=$PR_CAPTURES_DIR/diffs/

mkdir $DIFF_DIR &> /dev/null

# make *.png expand to empty if there's no png file
setopt nullglob  &> null # zsh
shopt -s nullglob &> null # bash

# Let's accumulate the results in these arrays
# so we can print them in one go in a single PR comment if we want

images_with_differences=()
new_images_in_pr=()
images_missing_in_pr=()

for i in "${PR_CAPTURES_DIR}/*.png" ; do
    image_name=`basename $i`
    reference_image=$REFERENCE_CAPTURES_DIR/$image_name

    if [[ -f $reference_image ]] ; then
        if ! compare $PR_CAPTURES_DIR/$image_name $reference_image "$DIFF_DIR/${image_name}_diff.png" ; then
            images_with_differences+=($image_name)
        fi
    else
        new_images_in_pr+=($image_name)
    fi
done

if [[ ${#images_with_differences[@]} -eq 0 && ${#new_images_in_pr[@]} -eq 0 && ${#images_missing_in_pr[@]} -eq 0 ]]; then
    # all arrays are empty, no diffs to report
    exit 0
fi


pr_text=""

if [[ ${#images_with_differences[@]} -ne 0 ]] ; then
    echo "found differences ${#images_with_differences}"
fi

if [[ ${#new_images_in_pr[@]} -ne 0 ]] ; then
    pr_text+="* PR has new images * \n"
    for i in "${new_images_in_pr[@]}" ; do
        pr_text+=$i
    done
fi

if [[ -n "$pr_text" ]]; then

    echo "Creating PR comment with content"
    echo -e "$pr_text"

    # Variable is not empty, create PR comment
    gh pr comment $PR_NUMBER --body $pr_text
fi

# for i in $REFERENCE_CAPTURES_DIR/*.png ; do
#     image_name=`basename $i`
#     if ! [ -f $PR_CAPTURES_DIR/$image_name ] ; then
#         images_missing_in_pr+=($image_name)
#     fi
# done

# for i in ${images_with_differences[@]} ; do
#     echo "Detected image differences for $i"
# done



# for i in ${images_missing_in_pr[@]} ; do
#     echo "Image $i wasn't generated"
# done
