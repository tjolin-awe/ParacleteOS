NASM = nasm
QEMU = qemu-system-i386
IMG  = os.img

all: $(IMG)
	$(QEMU) -fda $(IMG)

run:
	$(QEMU) -fda $(IMG)

$(IMG): boot.bin kernel.bin
	powershell -ExecutionPolicy Bypass -File build_img.ps1

boot.bin: boot/boot.asm
	$(NASM) -f bin boot/boot.asm -o boot.bin

kernel.bin: kernel/kernel.asm
	$(NASM) -f bin kernel/kernel.asm -o kernel.bin

build: boot.bin kernel.bin $(IMG)

clean:
	del /f boot.bin kernel.bin $(IMG)