desc 'Sets up the environment'
task :setup do
  require 'fileutils'

  # Import the gems into RVM
  if `which rvm`.empty?
    puts 'It seems RVM is not installed, please install the following ' \
      'gems manually:'
    puts

    puts File.read(File.expand_path('../../.gems', __FILE__))
  else
    sh('rvm gemset import .gems')
  end

  # Copy the configuration files
  config_path = File.expand_path('../../config', __FILE__)

  ['config.default.rb', 'database.default.rb', 'unicorn.default.rb'].each do |a|
    b = a.gsub('.default', '')

    unless File.exist?(b)
      FileUtils.cp(File.join(config_path, a), File.join(config_path, b))
    end
  end
end
