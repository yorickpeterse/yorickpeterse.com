desc 'Deploys the website'
task :deploy => [:build] do
  sh 'nanoc deploy'
end
