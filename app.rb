require 'zen'
require 'rdiscount'

require __DIR__('config/config')
require __DIR__('config/database')
require __DIR__('config/routes')
require __DIR__('theme/yorickpeterse')
require __DIR__('markup')

FrontendAsset = Ramaze::Asset::Environment.new(
  :cache_path => __DIR__('public/minified'),
  :minify     => Ramaze.options.mode == :live
)

FrontendAsset.serve(
  :css,
  [
    'yorickpeterse/css/reset',
    'yorickpeterse/css/grid',
    'yorickpeterse/css/github',
    'yorickpeterse/css/style',
  ],
  :name => 'yorickpeterse'
)

FrontendAsset.build(:css)

Zen.start
