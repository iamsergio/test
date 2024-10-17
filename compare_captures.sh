# SPDX-FileCopyrightText: 2023 Klarälvdalens Datakonsult AB, a KDAB Group company <info@kdab.com>
# SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only

#!/bin/sh

if [ "$#" -ne 2 ] ; then
    echo "Usage: compare_captures.sh <reference_capture_dir> <current_capture_dir>"
    exit 1
fi

REFERENCE_CAPTURES=$1
PR_CAPTURES_DIR=$2

# Let's accumulate the results in these arrays
# so we can print them in one go in a single PR comment if we want

images_with_differences=()
new_images_in_pr=()
images_missing_in_pr=()


for i in build/captures/*.png ; do
    image_name=`basename $i`
    reference_image=$REFERENCE_CAPTURES/$image_name

    if [ -f $reference_image ]; then
        if ! compare build/captures/$image_name $reference_image "build/captures/${image_name}_diff.png" ; then
            images_with_differences+=($image_name)
        fi
    else
        new_images_in_pr+=($image_name)
    fi
done

for i in $REFERENCE_CAPTURES/*.png ; do
    image_name=`basename $i`
    if ! [ -f $PR_CAPTURES_DIR/$image_name ] ; then
        images_missing_in_pr+=($image_name)
    fi
done

for i in ${images_with_differences[@]} ; do
    echo "Detected image differences for $i"
done

for i in ${new_images_in_pr[@]} ; do
    echo "New image $i, pushing to PR"
done

for i in ${images_missing_in_pr[@]} ; do
    echo "Image $i wasn't generated"
done
