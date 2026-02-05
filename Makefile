SITE := yorickpeterse.com

build:
	@inko build
	@./build/debug/main

release:
	@inko build --release
	@./build/release/main

watch:
	@bash scripts/watch.sh

clean:
	@rm -rf public build

deploy: build
	scripts/rclone.sh public "/var/lib/shost/${SITE}"

.PHONY: build watch clean deploy release ssh
