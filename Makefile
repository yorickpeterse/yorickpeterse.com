# The Cloudflare Pages project to deploy to.
PROJECT := yorickpeterse-com

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
	@npx wrangler pages deploy --project-name ${PROJECT} public

.PHONY: setup build watch clean deploy
