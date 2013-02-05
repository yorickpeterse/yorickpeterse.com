desc 'Deploys the website'
task :deploy => [:clean] do
  sh('nanoc')
  sh('nanoc deploy')
end
