desc 'Builds the website'
task :build do
  sh 'bundle exec middleman build'
end
