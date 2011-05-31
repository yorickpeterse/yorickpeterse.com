# Load the Zen gem
require 'zen'
require 'rdiscount'
require 'ramaze/log/rotatinginformer'

# Load the configuration files
require __DIR__('config/config')

# Load all our custom Rack middlewares
require __DIR__('config/middlewares')

# Load the database configuration file
require __DIR__('config/database')

# Load all routes
require __DIR__('config/routes')

# Make sure that Ramaze knows where you are
Ramaze.options.roots.push(Zen.root)

# Load the database
Zen.init

# Require all the custom gems/modules we need
require __DIR__('theme/yorickpeterse')
require __DIR__('plugin/markup')

require 'zen/package/all'

Zen.post_init
