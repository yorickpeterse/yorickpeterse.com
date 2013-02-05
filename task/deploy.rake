desc 'Deploys the website'
task :deploy do
  sh('nanoc')
  sh('nanoc deploy')
end
