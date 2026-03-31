#!/bin/bash

set -o pipefail
source .env 2>/dev/null || { echo "❌ .env not found"; exit 1; }

# ========== CONFIG ==========
ROM="Lineage-19.1"; DEV="RMX2195"; TYPE="userdebug"; VER="12.1"; MAIN="mnrdnn"
OUT="out/target/product/${DEVICE:-$DEV}"; LOG="build.log"; START=$(date +%s)
JOBS=$(nproc); export TZ="Asia/Jakarta"

FINAL_NAME="${ROM}-${DEV}-${VER}-$(date +%Y%m%d)"

# ========== COLORS ==========
C='\033[0;36m'; G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; N='\033[0m'

# ========== TELEGRAM ==========
tg() { curl -s -X POST "https://api.telegram.org/bot${TT}/sendMessage" -d "chat_id=${CI}" -d "parse_mode=HTML" --data-urlencode "text=$1" >/dev/null; }
tg_edit() { curl -s -X POST "https://api.telegram.org/bot${TT}/editMessageText" -d "chat_id=${CI}" -d "message_id=$1" --data-urlencode "text=$2" >/dev/null; }
tg_doc() { curl -fsSL -X POST -F document=@"$1" "https://api.telegram.org/bot${TT}/sendDocument" -F "chat_id=${CI}" -F "parse_mode=HTML" -F "caption=$2" >/dev/null; }

# ========== UPLOAD ==========
pd_upload() { 
    [ ! -f "$1" ] && echo "NOT_FOUND" && return
    ID=$(curl -sS -T "$1" -u :$PD https://pixeldrain.com/api/file/ | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
    [ -n "$ID" ] && echo "https://pixeldrain.com/u/$ID" || echo "FAILED"
}
gf_upload() {
    for s in store2 store3 store4 store5; do
        URL=$(curl -s -F "file=@$1" "https://${s}.gofile.io/uploadFile" | sed -n 's/.*"downloadPage":"\([^"]*\)".*/\1/p')
        [ -n "$URL" ] && echo "$URL" && return
    done; echo "FAILED"
}

# ========== BUILD ==========
echo -e "${C}🕒 Build started at $(date)${N}"
tg "Build started
✨ ${ROM}-${DEV} | ${TYPE}
📦 ${FINAL_NAME}
👤 ${MAIN}
🌏 $(date +'%d %b %Y %H:%M')"

# Install dependencies
echo -e "${Y}📦 Installing deps...${N}"
sudo apt-get update -y && sudo apt-get install -y patchelf coreutils 
sudo ln -sf /usr/lib/x86_64-linux-gnu/libncurses.so.6 /usr/lib/x86_64-linux-gnu/libncurses.so.5 2>/dev/null
sudo ln -sf /usr/lib/x86_64-linux-gnu/libtinfo.so.6 /usr/lib/x86_64-linux-gnu/libtinfo.so.5 2>/dev/null

# Clean
echo -e "${Y}🧹 Clean up...${N}"
rm -rf build/soong/fsgen .repo/local_manifests prebuilts/clang/host/linux-x86 $OUT \
       device/realme/$DEV vendor/realme/$DEV device/realme/sm4250-common \
       kernel/realme/sm4250-common vendor/realme/sm4250-common

# Init & Sync
repo init -u https://github.com/LineageOS/android.git -b lineage-19.1 --git-lfs

# Clone trees
git clone https://github.com/SM4250-Dev/device_realme_RMX2195 device/realme/$DEV -b 12.1 --depth=1
git clone https://github.com/SM4250-Dev/device_realme_sm4250-common device/realme/sm4250-common -b 12.1 --depth=1
git clone https://github.com/SM4250-Dev/vendor_realme_RMX2195 vendor/realme/$DEV -b 12.1 --depth=1
git clone https://github.com/SM4250-Dev/vendor_realme_sm4250-common vendor/realme/sm4250-common -b 12.1 --depth=1
git clone https://github.com/LineageOS/android_kernel_oneplus_sm4250.git kernel/realme/sm4250-common --depth=1 -b lineage-20

# Sync
repo sync -c --force-sync --no-tags -j$JOBS || { tg "❌ Sync failed"; exit 1; }

# Setup
. build/envsetup.sh
export BUILD_USERNAME=$MAIN BUILD_HOSTNAME=crave
lunch lineage_${DEV}-${TYPE}

# Monitor
MSG=$(curl -s -X POST "https://api.telegram.org/bot${TT}/sendMessage" -d "chat_id=${CI}" -d "text=⚙️ Initialized ..." -d "parse_mode=HTML")
MID=$(echo "$MSG" | sed -n 's/.*"message_id":\([0-9]*\).*/\1/p')
( while true; do
    sleep 30
    STATUS=$(tail -n 30 "$LOG" 2>/dev/null | grep -E '\[[0-9]+%\]|[0-9]+%|Building' | tail -1)
    [ -z "$STATUS" ] && STATUS=$(tail -1 "$LOG" 2>/dev/null | cut -c1-60)
    [ -n "$STATUS" ] && tg_edit "$MID" "⏳ Build Starting...
⏳ ${STATUS:0:100}
Last Update: $(date +'%H:%M')"
done ) &
MON_PID=$!
# Build
make bacon -j$JOBS 2>&1 | tee "$LOG"

if [ ${PIPESTATUS[0]} -ne 0 ]; then 
    kill $MON_PID 2>/dev/null
    LOG_SIZE=$(stat -c%s "$LOG" 2>/dev/null || stat -f%z "$LOG" 2>/dev/null)
    
    if [ "$LOG_SIZE" -le 52428800 ] 2>/dev/null; then 
      tg_doc "$LOG" "Build Log - ${DEV}"
    else
      tg "❌ Build failed! - $(gf_upload "$LOG")"
    fi
    for img in boot dtbo recovery; do
        [ -f "$OUT/${img}.img" ] && tg "${img}.img: $(gf_upload "$OUT/${img}.img")"
    done
    exit 1
fi
kill $MON_PID 2>/dev/null

# ========== RENAME ZIP ==========
ZIP=$(ls -t $OUT/*.zip 2>/dev/null | head -1)
if [ -n "$ZIP" ] && [ -f "$ZIP" ]; then
    # Get original filename
    ORIGINAL_NAME=$(basename "$ZIP")
    
    # Create final path
    FINAL_ZIP="${OUT}/${FINAL_NAME}.zip"
    
    # Rename the zip
    mv "$ZIP" "$FINAL_ZIP"
    ZIP="$FINAL_ZIP"
    
fi

# ========== UPLOAD ==========
DUR=$(($(date +%s)-START))

if [ -n "$ZIP" ] && [ -f "$ZIP" ]; then
    SIZE=$(du -h "$ZIP" | awk '{print $1}')
    PD_URL=$(pd_upload "$ZIP")
    
    tg "✅ Build complete!
✨ ${ROM}-${DEV} | ${TYPE}
📦 ${FINAL_NAME}
📏 ${SIZE}
⏱️ $((DUR/3600))h $(((DUR%3600)/60))m
Download: ${PD_URL}"
    
    # Upload images
    for img in boot dtbo recovery; do
        [ -f "$OUT/${img}.img" ] && tg "${img}.img: $(gf_upload "$OUT/${img}.img")"
    done
fi

# Upload log
LOG_SIZE=$(stat -c%s "$LOG" 2>/dev/null || stat -f%z "$LOG" 2>/dev/null)
[ -f "$LOG" ] && [ "$LOG_SIZE" -le 52428800 ] && tg_doc "$LOG" "Build Log - ${DEV}"

tg "🥀 Artifacts released!"
echo -e "${G}✅ Done! Time: $((DUR/60)) minutes${N}"
