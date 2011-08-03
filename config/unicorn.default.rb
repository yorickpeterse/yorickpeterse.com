# The working directory, should be an absolute path.
working_directory File.expand_path('../../', __FILE__)

# The amount of worker processes to use. IMPORTANT: when using more than one
# worker you won't be able to use the in-memory cache that Ramaze uses by
# default as this will force people to login again in case their request is
# handled by a different worker.
worker_processes 2

# Preloads the application (such as configuration files and controllers) into
# memory.  It's recommended to set this to true.
preload_app true

# The port to serve the website on. It's best to use a server such as Nginx to
# proxy all calls from port 80 to this port.
#listen 7000

# The Unix socket to listen to for incoming connections. Unix sockets are
# recommended as they're much faster than listening to a port. The value of this
# option should be the full path to the socket.
listen 'path/to/socket.sock'

# The user and user group to use for the application. It's recommended to assign
# a separate user to the website so that in the event of a system breach the
# hacker (or the application itself) can't nuke your server.
user 'USER', 'GROUP'

# Nuke workers after 30 seconds of not doing anything useful
timeout 30

# PID path relative to working_directory
pid 'tmp/unicorn.pid'

# Log settings, relative to working_directory
stderr_path 'log/unicorn/stderr.log'
stdout_path 'log/unicorn/stdout.log'
