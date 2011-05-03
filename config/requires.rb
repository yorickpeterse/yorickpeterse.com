require __DIR__('../vendor/theme/yorickpeterse/lib/yorickpeterse')

# Load all core extensions that ship with Zen. 
require 'zen/package/all'

# Load all custom plugins
require __DIR__('../vendor/plugin/markup')

##
# All custom gems can go in here.
#
# require 'rdiscount'
# require 'foobar'
require 'rdiscount'
