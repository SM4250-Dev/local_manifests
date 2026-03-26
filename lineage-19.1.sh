#! /bin/bash

rm -rf .repo/local_manifests; \

repo init -u https://github.com/LineageOS/android.git -b lineage-19.1 --git-lfs

rm -rf prebuilts/clang/host/linux-x86; \

/opt/crave/resync.sh; \



rm -rf out/target/product/RMX2195; \
rm -rf device/realme/RMX2195; \
rm -rf vendor/realme/RMX2195; \
rm -rf device/realme/sm4250-common; \
rm -rf kernel/realme/sm4250-common; \
rm -rf vendor/realme/sm4250-common; \


# Device Tree
git clone https://github.com/SM4250-Dev/device_realme_RMX2195 device/realme/RMX2195 -b 12.1 --depth=1; \
# Common
git clone https://github.com/SM4250-Dev/device_realme_sm4250-common device/realme/sm4250-common -b 12.1 --depth=1; \

# Vendor
git clone https://github.com/SM4250-Dev/vendor_realme_RMX2195 vendor/realme/RMX2195 -b 12.1 --depth=1; \
git clone https://github.com/SM4250-Dev/vendor_realme_sm4250-common vendor/realme/sm4250-common -b 12.1 --depth=1; \

# Kernel
git clone https://github.com/SM4250-Dev/android_kernel_realme_RMX2195 kernel/realme/sm4250-common --depth=1 -b Skywalker-backup ; \

. build/envsetup.sh; \
export BUILD_USERNAME=udyneos
export BUILD_HOSTNAME=craveoss

brunch RMX2195 userdebug && make bacon  ; \
