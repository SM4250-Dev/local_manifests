#!/bin/bash

set -o pipefail
set -o allexport
source .env
set +o allexport

# ================= COLORS =================
cyan='\033[0;36m'
blue='\033[0;34m'
green='\033[0;32m'
yellow='\033[1;33m'
red='\033[0;31m'
nocol='\033[0m'

# ================= TIMEZONE =================
echo -e "${cyan}🕒 Switching system timezone to Asia/Jakarta ${nocol}"
export TZ="Asia/Jakarta"

echo -e "${cyan}🕒 Current system time: $(date)${nocol}"

# ================= ROM INFO =================
ROM_NAME="Lineage-18.1"
DEVICE="RMX2195"
BUILD_TYPE="userdebug"
ANDROID_VERSION="11.1"
SECURITY_PATCH="Maret"
ROM_VERSION="11.1 Test"
MAINTAINER="mnrdnn"

OUT_DIR="out/target/product/${DEVICE}"
START_TIME=$(date +%s)
BUILD_LOG="build.log"
ERROR_LOG="error_log.txt"

if [ -z "$TT" ] || [ -z "$CI" ] || [ -z "$PD" ] || [ -z "$GT" ]; then
  echo -e ".env gagal di setup"
else
  echo -e ".env berhasil di setup"
fi

# ================= TELEGRAM =================
tg_send() {
    curl -s -X POST "https://api.telegram.org/bot${TT}/sendMessage" \
        -d "chat_id=${CI}" \
        -d "parse_mode=HTML" \
        -d "disable_web_page_preview=true" \
        --data-urlencode "text=$1" >/dev/null
}

tg_edit() {
    curl -s -X POST "https://api.telegram.org/bot${TT}/editMessageText" \
        -d "chat_id=${CI}" \
        -d "message_id=$1" \
        -d "parse_mode=HTML" \
        --data-urlencode "text=$2" >/dev/null
}

tg_upload() {
    curl -s -X POST "https://api.telegram.org/bot${TT}/sendMessage" \
        -d "chat_id=${CI}" \
        -d "parse_mode=HTML" \
        -d "disable_web_page_preview=true" \
        --data-urlencode "text=$1" >/dev/null
}

# ================= PIXELDRAIN =================
pixeldrain_upload() {
    local FILE="$1"
    [ ! -f "$FILE" ] && echo "NOT_FOUND" && return
    RESP=$(curl -sS -T "$FILE" -u :$PD https://pixeldrain.com/api/file/)
    ID=$(echo "$RESP" | grep -oP '(?<="id":")[^"]+')
    [ -n "$ID" ] && echo "https://pixeldrain.com/u/$ID" || echo "UPLOAD_FAILED"
}

# ================= GOFILE =================
gofile_upload() {
    local FILE="$1"
    for S in store2 store3 store4 store5; do
        RESP=$(curl -s -F "file=@${FILE}" "https://${S}.gofile.io/uploadFile")
        echo "$RESP" | grep -q '"status":"ok"' && \
        echo "$RESP" | grep -oP '(?<=downloadPage":")[^"]+' && return
    done
    echo "UPLOAD_FAILED"
}

# ================= FAIL =================
on_fail() {
    ERR_LINK="N/A"
    [ -f out/error.log ] && ERR_LINK=$(gofile_upload out/error.log)

    tg_send "💥 Compilation failed
📱 Codename: ${DEVICE}
📄 Check Build Logs"

    tg_upload "💥 Compilation failed
📱 Codename: ${DEVICE}
📄 Error log: ${ERR_LINK}"

    exit 1
}
# ================= BUILD START =================
tg_send "✨ ${ROM_NAME} buildbot started
📱 Codename: ${DEVICE}
🧪 Build Type: ${BUILD_TYPE}
⚙️ Version: ${ROM_VERSION}
⚓️ Android: ${ANDROID_VERSION}
🛡 Patch: ${SECURITY_PATCH}
👤 Maintainer: ${MAINTAINER}
🌏 $(date +"%d %b %Y %I:%M %p WIB")"

# ================= BUILD =================
echo -e "${blue}>>>> [STEP] Setup + Clean${nocol}"

sudo apt-get update -y
sudo apt-get install -y patchelf coreutils
sudo ln -s /usr/lib/x86_64-linux-gnu/libncurses.so.6 /usr/lib/x86_64-linux-gnu/libncurses.so.5
sudo ln -s /usr/lib/x86_64-linux-gnu/libtinfo.so.6 /usr/lib/x86_64-linux-gnu/libtinfo.so.5

rm -rf build/soong/fsgen
rm -rf .repo/local_manifests; \
rm -rf prebuilts/clang/host/linux-x86; \
rm -rf out/target/product/RMX2195; \
rm -rf device/realme/RMX2195; \
rm -rf vendor/realme/RMX2195; \
rm -rf device/realme/sm4250-common; \
rm -rf kernel/realme/sm4250-common; \
rm -rf vendor/realme/sm4250-common; \

echo -e "${blue}>>>> [STEP] Repo Init${nocol}"
repo init -u https://github.com/LineageOS/android.git -b lineage-18.1 --git-lfs
echo -e "${blue}>>>> [STEP] Local Manifests${nocol}"
# Device Tree
git clone https://github.com/SM4250-Dev/device_realme_RMX2195 device/realme/RMX2195 -b 12.1 --depth=1; \
# Common
git clone https://github.com/SM4250-Dev/device_realme_sm4250-common device/realme/sm4250-common -b 12.1 --depth=1; \
# Vendor
git clone https://github.com/SM4250-Dev/vendor_realme_RMX2195 vendor/realme/RMX2195 -b 12.1 --depth=1; \
git clone https://github.com/SM4250-Dev/vendor_realme_sm4250-common vendor/realme/sm4250-common -b 12.1 --depth=1; \
# Kernel
git clone https://github.com/SM4250-Dev/android_kernel_realme_RMX2195 kernel/realme/sm4250-common --depth=1 -b Skywalker-backup ; \
echo -e "${yellow}>>>> [STEP] Repo Sync (this will take time)${nocol}"
if [ -f /opt/crave/resync.sh ]; then
    /opt/crave/resync.sh
else
    repo sync -c --force-sync --no-tags --no-clone-bundle -j$(nproc --all)
fi

echo -e "${green}>>>> [STEP] Export info & Build${nocol}"
. build/envsetup.sh
export BUILD_USERNAME=mnrdnn
export BUILD_HOSTNAME=crave
lunch lineage_${DEVICE}-${BUILD_TYPE} ; \
# ================= LIVE MONITOR =================
: > build.log

MSG_JSON=$(curl -s -X POST "https://api.telegram.org/bot${TT}/sendMessage" \
    -d "chat_id=${CI}" \
    -d "text=⚙️ <b>Compilation Started...</b>" \
    -d "parse_mode=HTML")
MSG_ID=$(echo "$MSG_JSON" | grep -oP '"message_id":\K[0-9]+')

live_monitor() {
    local msg_id=$1
    local last_status=""
    while true; do
        sleep 60
        if [ -f "$BUILD_LOG" ]; then
            # Get last 20 lines and find compilation status
            STATUS=$(tail -n 20 "$BUILD_LOG" | grep -E '\[.*%[[:space:]]+[0-9]+/[0-9]+\]|ninja:|make:' | tail -n 1)
            
            if [[ -z "$STATUS" ]]; then
                STATUS=$(tail -n 1 "$BUILD_LOG" | cut -c1-60)
            fi
            
            if [[ "$STATUS" != "$last_status" && ! -z "$STATUS" ]]; then
                tg_edit "$msg_id" "⏳ Compiling status...
<code>${STATUS}</code>
<i>Last Update: $(date +'%I:%M %p')</i>"
                last_status="$STATUS"
            fi
        else
            tg_edit "$msg_id" "⏳ Compiling status...
<code>Compiling ROM ...</code>
<i>Last Update: $(date +'%I:%M %p')</i>"
        fi
    done
}

# Start monitor in background
live_monitor "$MSG_ID" &
MONITOR_PID=$!

# Start the build
set -o pipefail
make bacon -j$(nproc --all) 2>&1 | tee "$BUILD_LOG"

kill $MONITOR_PID 2>/dev/null
MONITOR_PID=""

if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    on_fail
fi
# ================= SUCCESS =================
END_TIME=$(date +%s)
DUR=$((END_TIME - START_TIME))

BUILD_ID="UNKNOWN"
ROM_ZIP=$(ls -1 ${OUT_DIR}/*.zip 2>/dev/null | sort | tail -n 1)
if [ -n "$ROM_ZIP" ]; then
    BUILD_ID=$(basename "$ROM_ZIP" .zip)
    ROM_SIZE=$(du -h "$ROM_ZIP" | awk '{print $1}')
else
    ROM_SIZE="Unknown"
fi

tg_send "🌌 Buildbot finished it's job
📱 Codename: ${DEVICE}
🧩 Build Type: ${BUILD_TYPE}
🆔 Build ID: <code>${BUILD_ID}</code>
📦 Size: ${ROM_SIZE}
👤 Maintainer: ${MAINTAINER}
⏳ Compilation took $((DUR/3600))h $(((DUR%3600)/60))min"

tg_send "🚨 Compile Success. Uploading artifacts…"

# ================= UPLOAD =================
echo -e "${green}>>>> [STEP] Upload Artifacts${nocol}"

PRIVATE_MSG="📦 ${ROM_NAME} Uploads
📱 Device: ${DEVICE}
🧩 Build Type: ${BUILD_TYPE}
"

ROM_ZIP=$(ls -t ${OUT_DIR}/*.zip 2>/dev/null | head -n 1)

if [ -n "$ROM_ZIP" ]; then
    PRIVATE_MSG+="📄 ROM: $(basename "$ROM_ZIP")
GoFile: $(gofile_upload "$ROM_ZIP")
PixelDrain: $(pixeldrain_upload "$ROM_ZIP")
"
fi

for IMG in boot.img dtbo.img vendor.img super_empty.img recovery.img; do
    FILE="${OUT_DIR}/${IMG}"
    [ -f "$FILE" ] && PRIVATE_MSG+="🧩 ${IMG}
GoFile: $(gofile_upload "$FILE")
PixelDrain: $(pixeldrain_upload "$FILE")
"
done

OTA_JSON="${OUT_DIR}/GMS/${DEVICE}.json"

if [ -f "$OTA_JSON" ]; then
    PRIVATE_MSG+="📑 OTA JSON: $(basename "$OTA_JSON")
GoFile: $(gofile_upload "$OTA_JSON")
PixelDrain: $(pixeldrain_upload "$OTA_JSON")

"
fi

tg_upload "$PRIVATE_MSG"
tg_send "🥀 Artifacts released into the wild."
