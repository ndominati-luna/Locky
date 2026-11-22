#!/bin/zsh
# Builds the encrypted HLS stream of the About easter egg (the video of the first Locky) from a
# video file. Upload the output folder, as is, to the hidden folder of the site named in
# Apps/iOS/Features/Story/LockyStory.swift (with its .htaccess: Apache serves .ts as Qt files).
#
#   Tools/Story/make_story_hls.sh <video> <key as 32 hex digits> <output folder>
#
# The key must be the one masked in LockyStory.swift: the playlists name it locky-story://key,
# which only the app answers. Five qualities (270p to 1080p), 4 s segments, keyframes every 2 s,
# AES-128 with the media sequence number as IV, the 540p variant listed first so that playback
# starts fast and climbs.
set -e
[[ $# -eq 3 ]] || { echo "usage: $0 <video> <key hex> <output folder>"; exit 1; }
input=$1 key=$2 out=$3
[[ ${#key} -eq 32 ]] || { echo "the key is 16 bytes: 32 hex digits"; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
echo -n "$key" | xxd -r -p > "$work/story.key"
printf 'locky-story://key\n%s/story.key\n' "$work" > "$work/keyinfo.txt"
mkdir -p "$out"
cd "$out"

ffmpeg -hide_banner -loglevel error -y -i "$input" \
    -filter_complex "[0:v]split=5[a][b][c][d][e];[a]scale=1920:1080[v0];[b]scale=1280:720[v1];[c]scale=960:540[v2];[d]scale=640:360[v3];[e]scale=480:270[v4]" \
    -map "[v0]" -map "[v1]" -map "[v2]" -map "[v3]" -map "[v4]" -map 0:a -map 0:a -map 0:a -map 0:a -map 0:a \
    -c:v libx264 -preset slow -profile:v high -pix_fmt yuv420p -g 48 -keyint_min 48 -sc_threshold 0 \
    -b:v:0 5000k -maxrate:v:0 5350k -bufsize:v:0 7500k \
    -b:v:1 2800k -maxrate:v:1 3000k -bufsize:v:1 4200k \
    -b:v:2 1600k -maxrate:v:2 1712k -bufsize:v:2 2400k \
    -b:v:3 800k -maxrate:v:3 856k -bufsize:v:3 1200k \
    -b:v:4 400k -maxrate:v:4 428k -bufsize:v:4 600k \
    -c:a aac -ac 2 -ar 48000 -b:a:0 128k -b:a:1 128k -b:a:2 128k -b:a:3 96k -b:a:4 64k \
    -f hls -hls_time 4 -hls_playlist_type vod -hls_flags independent_segments -hls_segment_type mpegts \
    -hls_key_info_file "$work/keyinfo.txt" -hls_segment_filename "%v/s%02d.ts" -master_pl_name master.m3u8 \
    -var_stream_map "v:0,a:0,name:1080p v:1,a:1,name:720p v:2,a:2,name:540p v:3,a:3,name:360p v:4,a:4,name:270p" \
    "%v/index.m3u8"

# ffmpeg uses one IV for every segment: encrypt each one again with its sequence number, the IV
# HLS takes when the playlist names none.
for variant in 1080p 720p 540p 360p 270p; do
    for segment in $variant/s*.ts; do
        number=$((10#${${segment:t:r}#s}))
        openssl aes-128-cbc -d -K "$key" -iv 00000000000000000000000000000000 -in "$segment" -out "$work/plain.ts"
        openssl aes-128-cbc -e -K "$key" -iv "$(printf '%032x' $number)" -in "$work/plain.ts" -out "$segment"
    done
    sed -i '' 's/,IV=0x[0-9a-fA-F]*//' $variant/index.m3u8
done

# The 540p variant first.
python3 -I - <<'EOF'
import re
text = open("master.m3u8").read()
head, *entries = re.split(r"\n(?=#EXT-X-STREAM-INF)", text.strip())
order = ["540p", "720p", "1080p", "360p", "270p"]
entries = sorted((e.strip() for e in entries), key=lambda e: order.index(e.split("\n")[1].split("/")[0]))
open("master.m3u8", "w").write(head.strip() + "\n" + "\n".join(entries) + "\n")
EOF

printf 'AddType video/mp2t .ts\nAddType application/vnd.apple.mpegurl .m3u8\n' > .htaccess
echo "Done: $(du -sh . | cut -f1) in $out"
