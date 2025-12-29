#! /bin/bash

rm -rf .repo/local_manifests; \

repo init -u https://github.com/LineageOS/android.git -b lineage-19.1 --git-lfs

rm -rf prebuilts/clang/host/linux-x86; \

/opt/crave/resync.sh; \



rm -rf out/target/product/RMX2195; \
rm -rf device/realme/RMX2195; \
rm -rf kernel/realme/RMX2195; \
rm -rf vendor/realme/RMX2195; \
rm -rf hardware/oplus; \


# Device Tree
git clone https://github.com/SM4250-Dev/device_realme_RMX2195 device/realme/RMX2195 -b main --depth=1; \
# Common
git clone https://github.com/SM4250-Dev/device_realme_bengal-common device/realme/bengal-common -b main --depth=1; \

# Vendor
git clone https://github.com/UdyneO2/android_vendor_realme_RMX2195 vendor/realme/RMX2195 -b main --depth=1; \
# Kernel
git clone https://github.com/SM4250-Dev/kernel_realme_RMX2195 kernel/realme/bengal --depth=1 -b rebase ; \

# Oplus
git clone https://github.com/crdroidandroid/android_hardware_oplus hardware/oplus -b 12.1 ; \

. build/envsetup.sh; \
export BUILD_USERNAME=udyneos
export BUILD_HOSTNAME=craveoss

brunch RMX2195 userdebug && make bacon  ; \
