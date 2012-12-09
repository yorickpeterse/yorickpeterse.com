desc 'Deploys the website'
task :deploy => [:compile, :merge] do
  sh('nanoc deploy')
end
