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
DIFF_DIR=$PR_CAPTURES_DIR/../diffs/
DIFFS_RELEASE_NAME=test_screen_captures
REFERENCE_RELEASE_NAME=reference_screen_captures-main # TODO we'll want more than one branch ?
REPO_NAME=iamsergio/test

mkdir $DIFF_DIR &> /dev/null

# make *.png expand to empty if there's no png file
setopt nullglob  &> /dev/null # zsh
shopt -s nullglob &> /dev/null # bash


# Download reference captures
gh release download $REFERENCE_RELEASE_NAME -p "*.png" -D $REFERENCE_CAPTURES_DIR

# Let's accumulate the results in these arrays
# so we can print them in one go in a single PR comment if we want

images_with_differences=()
new_images_in_pr=()
images_missing_in_pr=()

for i in "${PR_CAPTURES_DIR}/*.png" ; do
    image_name=`basename $i`
    reference_image=$REFERENCE_CAPTURES_DIR/$image_name

    if [[ -f $reference_image ]] ; then
        if [ compare -compose src $PR_CAPTURES_DIR/$image_name $reference_image "$DIFF_DIR/${PR_NUMBER}-${image_name}_diff.png" ] ; then
            echo "found differences for $image_name"
            images_with_differences+=($image_name)
            cp $PR_CAPTURES_DIR/$image_name $DIFF_DIR/${PR_NUMBER}-${image_name}
        fi
    else
        new_images_in_pr+=($image_name)
        cp $PR_CAPTURES_DIR/$image_name $DIFF_DIR/${PR_NUMBER}-${image_name}
    fi
done

if [[ ${#images_with_differences[@]} -eq 0 && ${#new_images_in_pr[@]} -eq 0 && ${#images_missing_in_pr[@]} -eq 0 ]]; then
    # Still useful to show a comment on success, in case PR has previous diff comments
    gh pr comment $PR_NUMBER --body "✅ No screencapture diffs to report!"

    # All is good now, when we merge, do not upload anything to reference_screen_captures
    gh release delete-asset test_screen_captures ${PR_NUMBER}-all-captures.tgz

    exit 0
fi

# Make sure the asset releases exist

if ! gh release list | grep -q "$DIFFS_RELEASE_NAME"  ; then
    echo "No asset release for diffs, creating..."
    gh release create ${DIFFS_RELEASE_NAME} --notes "Screen captures diffs for faulty pull requests"
fi

if ! gh release list | grep -q "$REFERENCE_RELEASE_NAME"  ; then
    echo "No asset release for reference capture, creating..."
    gh release create ${REFERENCE_RELEASE_NAME} --notes "Reference screen captures"
fi

echo "Uploading diffs..."
gh release upload ${DIFFS_RELEASE_NAME} $DIFF_DIR/*png --clobber || exit 1

tar cvzf ${PR_NUMBER}-all-captures.tgz -C "$(dirname $PR_CAPTURES_DIR)" "$(basename $PR_CAPTURES_DIR)"

# Once the PR gets merged we need to access this tgz as it will be the new reference
echo "Uploading all PR captures..."
gh release upload ${DIFFS_RELEASE_NAME} ${PR_NUMBER}-all-captures.tgz --clobber || exit 1

pr_text=""

if [[ ${#images_with_differences[@]} -ne 0 ]] ; then
    pr_text+="# PR produced different images:<br>"
    for i in "${images_with_differences[@]}" ; do
        pr_text+="### $i <br>"
        pr_text+="##### Got: ![$i](https://github.com/${REPO_NAME}/releases/download/${DIFFS_RELEASE_NAME}/${PR_NUMBER}-${i}) <br>"
        pr_text+="##### Expected: ![$i](https://github.com/${REPO_NAME}/releases/download/${REFERENCE_RELEASE_NAME}/${i}) <br>"
        pr_text+="##### Diff: ![$i](https://github.com/${REPO_NAME}/releases/download/${DIFFS_RELEASE_NAME}/${PR_NUMBER}-${i}_diff.png) <br>"
    done
fi

if [[ ${#new_images_in_pr[@]} -ne 0 ]] ; then
    pr_text+="# PR has new images:<br>"
    for i in "${new_images_in_pr[@]}" ; do
        pr_text+="- $i <br>"
        pr_text+="![$i](https://github.com/${REPO_NAME}/releases/download/${DIFFS_RELEASE_NAME}/${PR_NUMBER}-${i})"
    done
fi

if [[ ${#images_missing_in_pr[@]} -ne 0 ]] ; then
    pr_text+="# PR didn't produce the following images:<br>"
    for i in "${images_missing_in_pr[@]}" ; do
        pr_text+="$1"
    done
fi

if [[ -z "$pr_text" ]]; then
    # All files are the same
    rmdir $DIFF_DIR
else

    echo "Creating PR comment with content"
    echo -e "$pr_text"

    # Variable is not empty, create PR comment
    gh pr comment $PR_NUMBER --body "$pr_text"
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
