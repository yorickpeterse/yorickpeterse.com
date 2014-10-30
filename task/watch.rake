desc 'Builds the website using Guard'
task :watch do
  sh 'bundle exec guard start --no-interactions'
end
