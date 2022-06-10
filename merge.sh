#!/bin/bash

# Script to take a zipped folder of mp4 files, unzips these
# And generates a grid of these videos
# Example is how ffmpeg creates a grid
# ffmpeg -y -i 1.mp4 -i 2.mp4 -i 3.mp4 -i 4.mp4 -i 5.mp4 -i 6.mp4 -i 7.mp4 -i 8.mp4 -i 9.mp4 \
# -filter_complex "[0:v][1:v][2:v]hstack=inputs=3[top];[3:v][4:v][5:v]hstack=inputs=3[middle];[6:v][7:v][8:v]hstack=inputs=3[bottom];[top][middle][bottom]vstack=inputs=3[v]" \
# -map "[v]" \
# finalOutput.mp4

FRAMERATE=20
GRID_VERTICAL=3
GRID_HORIZONTAL=3
OUTPUT_RES_HEIGHT=1080
OUTPUT_RES_WIDTH=1920
TOTAL_GRIDS=$((GRID_VERTICAL * GRID_HORIZONTAL))
GRID_VIDEO_HEIGHT=$((OUTPUT_RES_HEIGHT / GRID_VERTICAL))
GRID_VIDEO_WIDTH=$((OUTPUT_RES_WIDTH / GRID_HORIZONTAL))
ZIPPED_PATH='./zipped'
UNZIP_PATH='./unzipped'
ORIGINAL_FILES=($UNZIP_PATH/*.mp4)
FILE_QUANTITY=${#ORIGINAL_FILES[@]}
TMP_CONVERTED_FOLDER='./converted'
TMP_CONVERTED_SUFFIX='-conv'
SPLASH_IMG_IN='./splash.png'
SPLASH_VID_OUT='./splash.mp4'
GRID_LIST=()
MERGED_DIR='./merged'
OUTPUT_PATH='./output.mp4'

# Remove files from previous run
if [ ! -d $UNZIP_PATH ]; then
 	mkdir -p $UNZIP_PATH;
else
	rm -rf  ${UNZIP_PATH}/*
fi

if [ ! -d $TMP_CONVERTED_FOLDER ]; then
 	mkdir -p $TMP_CONVERTED_FOLDER;
else
	rm -rf  ${TMP_CONVERTED_FOLDER}/*
fi

if [ ! -d $MERGED_DIR ]; then
 	mkdir -p $MERGED_DIR;
else
	rm -rf ${MERGED_DIR}/*
fi

rm -rf $SPLASH_VID_OUT
rm -rf $OUTPUT_PATH

# Unzip files
unzip ${ZIPPED_PATH}'/*.zip' -d ${UNZIP_PATH}'/' 1> /dev/null

# Create splash video
ffmpeg -y -framerate $FRAMERATE -loop 1 -i $SPLASH_IMG_IN -c:v libx264 -x264opts stitchable -t 1 -s "${GRID_VIDEO_WIDTH}x${GRID_VIDEO_HEIGHT}" -vf fps=$FRAMERATE -pix_fmt yuv420p $SPLASH_VID_OUT 2> /dev/null

# Loop through videos and generate grid merge files
for (( i=0; i<${TOTAL_GRIDS}; i++ ));
do
	MERGE_FILES=""
	
	for (( j=i; j<${FILE_QUANTITY}; j+=TOTAL_GRIDS ));
	do
		baseFileName=$(basename -- "${ORIGINAL_FILES[$j]}")
		extension="${baseFileName##*.}"
		filename="${baseFileName%.*}"
		convertedFileName="${TMP_CONVERTED_FOLDER}/${filename}${TMP_CONVERTED_SUFFIX}.${extension}"

		# Convert each video into a consistent format
		ffmpeg -y -i "${ORIGINAL_FILES[$j]}" -vcodec libx264 -s "${GRID_VIDEO_WIDTH}x${GRID_VIDEO_HEIGHT}" -r $FRAMERATE -an "$convertedFileName" 2> /dev/null

		MERGE_FILES+=$'file '$"'${convertedFileName}'"'\n'
	done
	
	MERGE_FILES+=$'file '$"'$SPLASH_VID_OUT'"'\n'
	echo -en $MERGE_FILES > "$i.txt"

	outputGridVideoFileName="${MERGED_DIR}/${i}.mp4"
	GRID_LIST+=(-i $outputGridVideoFileName)
	
	# Squash all videos together into it's grid
	ffmpeg -y -f concat -safe 0 -i "$i.txt" -c copy "$outputGridVideoFileName" 2> /dev/null
	
	# Remove Merge file after running ffmpeg
	rm "$i.txt"
done

# If only 1 video in grid copy it from merged folder
if [[ "$TOTAL_GRIDS" -eq 1 ]]; then
	cp "${MERGED_DIR}/0.mp4" $OUTPUT_PATH
	echo "Done"
	exit 0
fi

# Generate filter strings for final video conversion
filterComplexString=""
filterComplexSuffix=""

for (( i=0; i<${GRID_VERTICAL}; i++ ));
do
	for (( j=0; j<${GRID_HORIZONTAL}; j++ ));
	do
		filterComplexString+="[$(($i*$GRID_VERTICAL + $j)):v]"
		#echo "$(($i*$GRID_VERTICAL + $j))"
	done
	filterComplexString+="hstack=inputs=${GRID_HORIZONTAL}[r$i];"
	filterComplexSuffix+="[r$i]"
done
filterComplexSuffix+="vstack=inputs=$GRID_VERTICAL[v]"

# Generate final grid video
ffmpeg -y ${GRID_LIST[@]/#/} \
-filter_complex "${filterComplexString}${filterComplexSuffix}" \
-map "[v]" \
$OUTPUT_PATH 2> /dev/null

echo "Done"
