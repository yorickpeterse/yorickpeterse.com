TARGET := /var/lib/shost/yorickpeterse.com
USER := root
SERVER := web
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

deploy:
	@rclone sync --verbose \
		--multi-thread-streams=32 \
		--transfers 32 \
		--metadata \
		--checksum \
		--sftp-host $$(hcloud server ip ${SERVER}) \
		--sftp-user ${USER} \
		--sftp-port ${PORT} public/ :sftp:${TARGET}

deploy-github: build
	@echo -e "$${SSH_PRIVATE_KEY}" > deploy_key
	@rclone sync --verbose \
		--multi-thread-streams=32 \
		--transfers 32 \
		--metadata \
		--checksum \
		--sftp-host $$(hcloud server ip ${SERVER}) \
		--sftp-user ${USER} \
		--sftp-key-file deploy_key \
		--sftp-port ${PORT} public/ :sftp:${TARGET}
	@rm deploy_key

.PHONY: build watch clean deploy release ssh
