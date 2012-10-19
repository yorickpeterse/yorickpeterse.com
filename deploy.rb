require File.expand_path('../submodules/deployment/lib/deployment', __FILE__)

application = Deployment::Application.new do |app|
  app.name        = 'website'
  app.description = 'Personal website'
  app.directory   = '/srv/http/yorickpeterse.com'
  app.after       = ['postgresql.service', 'memcached.service']
  app.env         = {'RACK_ENV' => 'none'}
  app.command     = 'unicorn -E none -c config/unicorn.rb config.ru'
end

application.start!
