require 'zen'
require 'rdiscount'

require __DIR__('config/config')
require __DIR__('config/middlewares')
require __DIR__('config/database')
require __DIR__('config/routes')

# Require all the custom gems/modules we need
require __DIR__('theme/yorickpeterse')
require __DIR__('markup')

Zen.start
