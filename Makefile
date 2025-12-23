# The Cloudflare Pages project to deploy to.
PROJECT := yorickpeterse-com

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
	@npx wrangler pages deploy --project-name ${PROJECT} public

.PHONY: build watch clean deploy release
