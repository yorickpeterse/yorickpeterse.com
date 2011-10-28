def require_zen
  require File.expand_path('../app.rb', __FILE__)
  require 'zen/task'
end

task_dir = File.expand_path('../task', __FILE__)

# Load all tasks from ./task if the directory exists
if File.directory?(task_dir)
  Dir.glob("#{task_dir}/**/*.rake").each do |task|
    import task
  end
end

