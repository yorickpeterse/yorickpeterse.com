require 'bundler/setup'
require 'zen'
require 'redcarpet'

require __DIR__('config/config')
require __DIR__('config/database')
require __DIR__('config/routes')
require __DIR__('theme/yorickpeterse')

Zen.start
