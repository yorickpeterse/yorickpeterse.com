# The working directory, should be an absolute path.
working_directory File.expand_path('../../', __FILE__)

# The amount of worker processes to start.
worker_processes 2

# Preloads the application into memory.
preload_app false

# proxy all calls from port 80 to this port.
listen 7000
# listen 'path/to/unicorn.sock'

# The user and user group to use for the application.
# user 'USER', 'GROUP'

timeout 30

# PID path relative to working_directory
pid 'tmp/unicorn.pid'
