desc 'Removes files genreated by nanoc'
task :clean do
  tmp = File.expand_path('../../tmp', __FILE__)

  sh('rm -rf output')
  sh('rm -f crash.log')
  sh("rm -rf #{tmp}")
end
