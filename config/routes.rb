# Common routes
routes = {
  /^\/admin(.*)/            => '/admin%s',
  /^\/articles\/atom(.*)/   => '/articles/atom',
  /^\/articles\/(.*)\.md/   => '/articles/source/%s',
  /^\/articles(.*)/         => '/articles/entry%s'
}

routes.each { |regex, path| Ramaze::Route[regex] = path }
