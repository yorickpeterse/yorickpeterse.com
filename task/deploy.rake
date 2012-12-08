desc 'Deploys the website'
task :deploy => :compile do
  sh('rake merge')
  sh('nanoc deploy')
end
