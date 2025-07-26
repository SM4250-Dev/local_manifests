#! /bin/bash

rm -rf .repo/local_manifests; \

repo init -u https://github.com/LineageOS/android.git -b lineage-18.1 --git-lfs

rm -rf prebuilts/clang/host/linux-x86; \

/opt/crave/resync.sh; \



rm -rf out/target/product/RMX2195; \
rm -rf device/realme/RMX2195; \
rm -rf kernel/realme/RMX2195; \
rm -rf vendor/realme/RMX2195; \


# Device Tree
git clone https://github.com/SM4250-Dev/device_realme_RMX2195 device/realme/RMX2195 --depth=1; \
# Common
git clone https://github.com/SM4250-Dev/device_realme_bengal-common device/realme/bengal-common --depth=1; \

# Vendor
git clone https://github.com/SM4250-Dev/vendor_realme_RMX2195 vendor/realme/RMX2195 --depth=1; \
# Common
https://github.com/SM4250-Dev/vendor_realme_bengal-common vendor/realme/bengal-common --depth=1; \

# Kernel
git clone https://github.com/SM4250-Dev/kernel_realme_RMX2195 kernel/realme/RMX2195 --depth=1; \


. build/envsetup.sh; \
export BUILD_USERNAME=udyneos
export BUILD_HOSTNAME=crave

brunch RMX2195 userdebug && make bacon  ; \
