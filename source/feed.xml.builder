xml.instruct!
xml.feed 'xmlns' => 'http://www.w3.org/2005/Atom' do
  xml.id config[:website_url].chomp('/') + '/'
  xml.title config[:website_title]

  unless blog.articles.empty?
    xml.updated(blog.articles.first.date.to_time.iso8601)
  end

  xml.link href: config[:website_url], rel: 'alternate'
  xml.link href: URI.join(config[:website_url], current_page.path), rel: 'self'

  xml.author do
    xml.name config[:blog_author]
    xml.uri  config[:website_url]
  end

  blog.articles.each do |article|
    xml.entry do
      xml.id URI.join(config[:website_url], article.url)

      xml.title article.title

      xml.published article.date.to_time.iso8601
      xml.updated File.mtime(article.source_file).iso8601

      xml.link rel: 'alternate',
               href: URI.join(config[:website_url], article.url)

      xml.content article.body, type: 'html'
    end
  end
end
