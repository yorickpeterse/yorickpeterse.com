page '/*.xml', layout: false
page '/*.json', layout: false
page '/*.txt', layout: false
page '/*.ico', layout: false
page '/', layout: :home
page '/404.html', layout: :'404', directory_index: false

Time.zone = 'Europe/Amsterdam'

set :website_title, 'Yorick Peterse'
set :blog_author, 'Yorick Peterse'
set :website_url, 'http://yorickpeterse.com'
set :feed_url, "#{config[:website_url]}/feed.xml"

set :markdown_engine, :kramdown

set :markdown,
    fenced_code_blocks: true,
    parse_block_html: true,
    auto_ids: true,
    auto_id_prefix: 'header-',
    tables: true,
    input: 'GFM',
    hard_wrap: false

set :haml, ugly: true, format: :html5

activate :syntax, line_numbers: false

activate :blog do |blog|
  blog.prefix = 'articles'
  blog.sources = '{title}.html'
  blog.permalink = '{title}/index.html'
end

activate :directory_indexes

activate :s3_sync do |s3|
  s3.bucket = 'yorickpeterse.com'
  s3.region = 'eu-west-1'
  s3.acl = 'public-read'
  s3.index_document = 'index.html'
  s3.error_document = '404.html'
end

default_caching_policy max_age: 24 * 60 * 60

activate :cloudfront do |cf|
  cf.distribution_id = 'E38R9TE90MPQA7'
end

configure :development do
  activate :livereload
end

configure :build do
  activate :minify_css
  activate :asset_hash
end
