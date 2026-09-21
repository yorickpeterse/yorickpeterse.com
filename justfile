exe := "./build/release/main"
site := "yorickpeterse.com"
user := "web"
host := "web.srv.yorickpeterse.com"

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

new title: exe
    {{ exe }} article "{{ title }}"

# Build and deploy the website
[arg("flags", long)]
deploy flags="": build
    rsync \
        --archive \
        --checksum \
        --delete \
        --omit-dir-times \
        --progress \
        --rsh "ssh -o UserKnownHostsFile=known_hosts {{ flags }}" \
        public/ {{ user }}@{{ host }}:/var/lib/shost/sites/{{ site }}/

# Updates the known hosts file.
hosts:
    ssh-keyscan -q {{ host }} > known_hosts
