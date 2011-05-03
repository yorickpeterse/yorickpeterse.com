# Common routes
routes = {
  /\/admin(.*)/            => '/admin%s',
  /\/articles\/atom(.*)/   => '/articles/atom',
  /\/articles\/(.*)\.md/   => '/articles/source/%s', 
  /\/articles(.*)/         => '/articles/entry%s'
}

routes.each do |regex, path|
  Ramaze::Route[regex] = path
end

# Routes for all pages
Ramaze::Route['pages'] = lambda do |path, request|
  # Ignore 404 pages and blog pages
  if path =~ /\/404(.*)/ or path =~ /\/comments-form(.*)/
    return path
  end
end
