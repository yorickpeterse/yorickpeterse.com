# frozen_string_literal: true

require 'lib/inko_lexer'
require 'uglifier'

Haml::TempleEngine.disable_option_validator!

page '/*.xml', layout: false
page '/*.json', layout: false
page '/*.txt', layout: false
page '/*.ico', layout: false
page '/', layout: :home
page '/404.html', layout: :'404', directory_index: false

Time.zone = 'Europe/Amsterdam'

set :website_title, 'Yorick Peterse'
set :blog_author, 'Yorick Peterse'
set :website_url, 'https://yorickpeterse.com'
set :feed_url, "#{config[:website_url]}/feed.xml"
set :markdown_engine, :kramdown

set :markdown,
    fenced_code_blocks: true,
    parse_block_html: true,
    auto_ids: true,
    auto_id_prefix: 'header-',
    tables: true,
    input: 'GFM',
    hard_wrap: false,
    toc_levels: 1..3

set :haml, format: :html5

activate :syntax, line_numbers: false

activate :blog do |blog|
  blog.name = 'blog'
  blog.prefix = 'articles'
  blog.sources = '{title}.html'
  blog.permalink = '{title}/index.html'
end

activate :directory_indexes

configure :development do
  activate :livereload
end

configure :build do
  activate :minify_css
  activate :asset_hash
end

helpers do
  def last_updated_at(path)
    Time.at(Integer(`git log -1 --format=%ct #{path} 2>&1`.strip))
  end
end
