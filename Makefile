EXE := ./build/release/main
SITE := yorickpeterse.com

exe:
	@inko build --release

build: exe
	@${EXE} build

watch:
	@bash scripts/watch.sh

clean:
	@rm -rf public build

deploy: build
	scripts/rclone.sh public "/var/lib/shost/${SITE}"

.PHONY: exe build watch clean deploy release ssh
