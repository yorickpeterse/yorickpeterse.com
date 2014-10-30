desc 'Deploys the website'
task :deploy => [:build] do
  sh 'bundle exec nanoc deploy'
end
