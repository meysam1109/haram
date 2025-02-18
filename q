jobs:
  build_rom:
    runs-on: ubuntu-latest
    timeout-minutes: 360

    steps:
      - name: تنظیم فضای Swap برای بهبود عملکرد
        run: |
          if [[ $(swapon --show) ]]; then
            echo "Swap قبلاً فعال است."
          else
            sudo fallocate -l 8G /swapfile
            sudo chmod 600 /swapfile
            sudo mkswap /swapfile
            sudo swapon /swapfile
            echo "Swap setup complete"
          fi

      - name: بررسی و بازیابی کش ccache
        uses: actions/cache@v3
        with:
          path: ~/.ccache
          key: ccache-${{ runner.os }}-${{ github.run_id }}
          restore-keys: |
            ccache-${{ runner.os }}-
        continue-on-error: true

      - name: نصب ابزارهای موردنیاز
        run: |
          sudo apt update
          sudo apt install -y openjdk-17-jdk bc curl repo git-core \
                              gnupg flex bison gperf build-essential zip \
                              zlib1g-dev libc6-dev libncurses5-dev \
                              x11proto-core-dev libx11-dev libgl1-mesa-dev \
                              libxml2-utils xsltproc unzip python3 python3-pip \
                              android-tools-mkbootimg wget ccache simg2img lz4

      - name: دانلود و استخراج MIUI Fastboot
        run: |
          mkdir -p miui_rom
          cd miui_rom
          wget -O miui_fastboot_rom.tgz "https://bigota.d.miui.com/V14.0.6.0.TKPMIXM/chopin_global_images_V14.0.6.0.TKPMIXM_20240528.0000.00_13.0_global_253b98dc56.tgz"
          if [[ ! -f miui_fastboot_rom.tgz ]]; then
            echo "فایل MIUI دانلود نشد!" && exit 1
          fi
          tar -xvf miui_fastboot_rom.tgz --strip-components=1

      - name: استخراج کرنل، وندر و فریمور
        run: |
          mkdir -p extracted/
          cd miui_rom
          simg2img super.img super.raw.img
          mkdir super_extracted && cd super_extracted
          7z x ../super.raw.img -o.

          mkdir -p ../../vendor && mv system/vendor ../../vendor/
          mkdir -p ../../firmware && mv system/firmware ../../firmware/
          mkdir -p ../../kernel && mv boot.img ../../kernel/

      - name: بررسی استخراج صحیح
        run: |
          if [[ ! -d "vendor" || ! -d "firmware" || ! -f "kernel/boot.img" ]]; then
            echo "استخراج MIUI ROM ناموفق بود!" && exit 1
          fi

      - name: تنظیم مسیرهای ساخت
        run: |
          echo "KERNEL_DIR=$(pwd)/kernel" >> $GITHUB_ENV
          echo "VENDOR_DIR=$(pwd)/vendor" >> $GITHUB_ENV
          echo "FIRMWARE_DIR=$(pwd)/firmware" >> $GITHUB_ENV
