exe := "./build/release/main"
site := "yorickpeterse.com"

# Build the website executable
exe:
    inko build --release

# Build the website
build: exe
    {{ exe }} build

# Serve the website and rebuild it automatically
watch:
    bash scripts/watch.sh

# Remove all build files
clean:
    rm -rf public build

# Build and deploy the website
deploy: build
    scripts/rclone.sh public "/var/lib/shost/{{ site }}"
