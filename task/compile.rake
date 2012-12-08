desc 'Compiles the website from scratch'
task :compile do
  sh('nanoc compile')

  Rake::Task['merge'].invoke
end
