# The S3 bucket to upload the files to.
BUCKET := yorickpeterse.com

# The Cloudfront distribution.
DIST := E38R9TE90MPQA7

build:
	@inko build
	@./build/main

setup:
	@inko pkg sync

watch:
	@bash scripts/watch.sh

clean:
	@rm -rf public

deploy:
	@rclone sync \
		--config rclone.conf \
		--checksum \
		--header-upload 'Cache-Control:max-age=604800' \
		--s3-acl 'public-read' \
		public "production:${BUCKET}"
	@aws cloudfront create-invalidation \
		--distribution-id "${DIST}" \
		--paths '/*'

.PHONY: setup build watch clean deploy
