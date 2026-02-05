TARGET := /var/lib/shost/yorickpeterse.com
USER := root
SERVER := 157.90.20.117
PORT := 2222

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
	@rclone sync --quiet \
		--multi-thread-streams=32 \
		--transfers 32 \
		--metadata \
		--sftp-host ${SERVER} \
		--sftp-user ${USER} \
		--sftp-port ${PORT} public/ :sftp:${TARGET}

deploy-github: build
	@echo -e "$${SSH_PRIVATE_KEY}" > deploy_key
	@rclone sync --quiet \
		--multi-thread-streams=32 \
		--transfers 32 \
		--metadata \
		--sftp-host ${SERVER} \
		--sftp-user ${USER} \
		--sftp-key-file deploy_key \
		--sftp-port ${PORT} public/ :sftp:${TARGET}
	@rm deploy_key

.PHONY: build watch clean deploy release ssh
