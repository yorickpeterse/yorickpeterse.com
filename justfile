exe := "./build/release/main"
site := "yorickpeterse.com"
user := "root"
host := "web.srv.yorickpeterse.com"
port := "2222"

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
[arg("flags", long)]
deploy flags="": build
    rsync \
        --archive --omit-dir-times --checksum --recursive --delete --progress \
        --rsh "ssh -p {{ port }} -o UserKnownHostsFile=known_hosts {{ flags }}" \
        public/ {{ user }}@{{ host }}:/var/lib/shost/{{ site }}/

# Updates the known hosts file.
hosts:
    ssh-keyscan -q -p {{ port }} {{ host }} > known_hosts
