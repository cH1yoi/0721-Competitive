#!/bin/bash

DEMO_PATH="/home/hana/versus/left4dead2/demo"
TEMP_PATH="/home/hana/versus/left4dead2/demo_zips"
LOG_FILE="/home/hana/demo_compress.log"
MIN_AGE_SECONDS=1800    # 文件至少要存在30分钟
CHECK_INTERVAL=60       # 检查间隔60秒

mkdir -p $TEMP_PATH

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

is_file_complete() {
    local file="$1"
    
    local current_time=$(date +%s)
    local file_time=$(stat -c %Y "$file")
    local age=$((current_time - file_time))
    
    if [ $age -lt $MIN_AGE_SECONDS ]; then
        return 1
    fi
    
    local size1=$(stat -c %s "$file")
    sleep $CHECK_INTERVAL
    local size2=$(stat -c %s "$file")
    
    if [ "$size1" = "$size2" ]; then
        return 0
    else
        return 1
    fi
}

find $DEMO_PATH -name "*.dem" -type f -print0 | while IFS= read -r -d '' file; do
    filename=$(basename "$file" .dem)
    if [ ! -f "$TEMP_PATH/${filename}.zip" ]; then

        if ! is_file_complete "$file"; then
            log_message "Skip: ${filename}.dem is too new or still being written"
            continue
        fi
        
        zip -j "$TEMP_PATH/${filename}.zip" "$file"
        if [ $? -eq 0 ]; then
            rm "$file"
            log_message "Compressed: ${filename}.dem"
        else
            log_message "Failed to compress: ${filename}.dem"
        fi
    fi
done