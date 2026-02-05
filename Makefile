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
		--stats-one-line \
		--multi-thread-streams=32 \
		--transfers 32 \
		--progress \
		--metadata \
		--sftp-host ${SERVER} \
		--sftp-user ${USER} \
		--sftp-port ${PORT} public/ :sftp:${TARGET}

ssh:
	mkdir -p ~/.ssh
	echo "${SSH_PUBLIC_KEY}" > ~/.ssh/key.pub
	echo "${SSH_PRIVATE_KEY}" > ~/.ssh/key
	chmod 600 ~/.ssh/key
	ssh-agent -a "${SSH_AUTH_SOCK}" >/dev/null
	ssh-add ~/.key

.PHONY: build watch clean deploy release ssh
