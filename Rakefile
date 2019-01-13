# frozen_string_literal: true

require 'rake/clean'
require 'time'

CLEAN.include('build')

desc 'Generate a new article'
task :article, :title do |_, args|
  abort 'You must specify a title' unless args.title

  title = args.title.strip
  filename = title
    .downcase
    .gsub(/\s+/, '-')
    .gsub(/[^\p{Word}\-]+/, '')

  File.open("source/articles/#{filename}.html.md", 'w') do |handle|
    handle.puts <<~TEMPLATE.strip
      ---
      title: #{title}
      date: #{Time.now.utc.strftime('%Y-%m-%d %H:%M:%S %Z')}
      ---

      The article goes here.
    TEMPLATE
  end
end

desc 'Builds the website'
task :build do
  sh 'bundle exec middleman build'
end

desc 'Deploys the website'
task deploy: [:build] do
  sh 'bundle exec middleman s3_sync'
  sh 'aws cloudfront create-invalidation '\
    "--distribution-id #{ENV['DISTRIBUTION_ID']} --paths '/*'"
end

desc 'Builds the website and starts a server'
task :server do
  sh 'bundle exec middleman'
end

task default: :server
