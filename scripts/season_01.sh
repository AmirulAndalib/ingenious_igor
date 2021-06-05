#!/bin/bash

set -xv

printf "\nGetting Encoder Tools...\n"

wget -q "${Index_Base}/ffmpeg_SlimStaticBuild/ffmpeg"
wget -q "${Index_Base}/NeroAACCodec/linux/neroAacEnc"
chmod a+x ffmpeg neroAacEnc
sudo mv ffmpeg neroAacEnc /usr/local/bin/

printf "\nSetting Up Rclone with Config...\n"
curl -sL https://rclone.org/install.sh | sudo bash &>/dev/null
mkdir -p ~/.config/rclone
curl -sL "${RCLONE_CONFIG_URL}" > ~/.config/rclone/rclone.conf

printf "\nGetting File from Specific Season to Encode...\n"
aria2c -c -s16 -x16 -m20 --console-log-level=warn --summary-interval=30 --check-certificate=false \
  "${Index_Base}/TorrentXbot/MLB.S01.1080p.NF.WEBRip.DDP5.1.x264-TrollHD/Miraculous%20-%20Tales%20of%20Ladybug%20&%20Cat%20Noir%20S01E${EpNum}%201080p%20Netflix%20WEB-DL%20DD+%205.1%20x264-TrollHD.mkv"

printf "\nRemoving Unwanted Characters From Filename & Modifying For Conversion...\n"
INFILE="Miraculous - Tales of Ladybug & Cat Noir S01E${EpNum} 1080p Netflix WEB-DL DD+ 5.1 x264-TrollHD.mkv"
export INFILE
ConvertedName="$(echo "$INFILE" | sed 's/ - /-/g;s/ /./g;s/1080p.*/1080p/g')"
export ConvertedName
mv "$INFILE" "$ConvertedName.mkv"

sleep 2s

printf "\nWorking with %s for %sp Conversion\n\n" "$ConvertedName.mkv" "$ResCode"

# Resolution-specific variables
if [[ "$ResCode" == "360" ]]; then
  scale="iw/3:ih/3"
  vmax="380"
  vbuf="480"
elif [[ "$ResCode" == "540" ]]; then
  scale="iw/2:ih/2"
  vmax="500"
  vbuf="620"
else
  printf "\nSomething went wrong parsing Resolution.\n"
fi
export scale vmax vbuf

printf "\nConverting Audio With NeroAacEnc for moderate VBR Quality...\n"

# Audio Pan Setting for Downmixing 6ch to 2ch
FL="0.818*FC + 0.818*FL + 0.707*BL + 0.167*BR + 0.35*LFE"
FR="0.818*FC + 0.818*FR + 0.707*BR + 0.167*BL + 0.65*LFE"
export FL FR

ffmpeg -hide_banner -y \
  -i "$ConvertedName.mkv" -map_metadata -1 -map_chapters 0 \
  -avoid_negative_ts 1 -map 0:1 -c:a pcm_f32le -ar 44100 \
  -af "volume=1.8,pan=stereo|FL < $FL|FR < $FR" \
  -f wav aud_enhanced_f32le.wav

file aud_enhanced_f3le.wav || ls -lAog .

ls -lAog .

sleep 2s

neroAacEnc -q 0.26 -he -if aud_enhanced_f32le.wav -of aud_enhanced_nero.mp4 || printf "\nFailed\n"

printf "\nExtract Subtitle and Remove Unwanted Characters...\n"

ffmpeg -hide_banner -stats_period 5 -y \
  -i "$ConvertedName.mkv" -map 0:3 -codec ass subtitle.ass

sed -i 's/&lrm;//g;s/&rlm;//g' subtitle.ass

sleep 2s

printf "\nConverting Video and Joining Previously Converted Audio + Subtitle...\n"

ffmpeg -hide_banner -stats_period 10 -y \
  -i "$ConvertedName.mkv" -i aud_enhanced_nero.mp4 -i subtitle.ass \
  -map_metadata -1 -map_chapters 0 -map 0:v:0 -map 1:a:0 -map 2:s:0 \
  -vf "scale=$scale" -c:v libx265 -vtag hvc1 \
  -x265-params me=4:vbv-maxrate=$vmax:vbv-bufsize=$vbuf:rd=4:dynamic-rd=2 \
  -preset slow -tune animation -crf 21 -movflags faststart \
  -metadata:s:v title="Miraculous - Tales of Ladybug & Cat Noir | S01E${EpNum}" \
  -af "volume=1.2" -c:a copy -movflags disable_chpl \
  -metadata:s:1 language=english -metadata:s:2 language=english \
  -avoid_negative_ts 1 \
  "${ConvertedName/1080/$ResCode}.x265.mkv"

sleep 2s

ffmpeg -hide_banner -stats_period 5 -y \
  -ss 00:28.8 -i "${ConvertedName/1080/$ResCode}.x265.mkv" -t 100 -avoid_negative_ts 1 \
  -codec copy "${ConvertedName/1080/SneakPeak.$ResCode}.x265.mkv"

#sleep 2s

set +xv

#printf "\nUpload Files to TD...\n"

#rclone copy "${ConvertedName/1080/$ResCode}.x265.mkv" td:/Miraculous_Ladybug/Season_01/ -P
#rclone copy "${ConvertedName/1080/SneakPeak.$ResCode}.x265.mkv" td:/Miraculous_Ladybug/Season_01/ -P

#printf "\nJob Well Done!\n\n"

