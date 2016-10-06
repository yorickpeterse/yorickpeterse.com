desc 'Deploys the website'
task deploy: [:build] do
  sh 'bundle exec middleman s3_sync'
  sh 'bundle exec middleman invalidate'
end
