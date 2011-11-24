Zen::Theme.add do |theme|
  theme.name   = 'yorickpeterse'
  theme.author = 'Yorick Peterse'
  theme.about  = 'Theme for my personal website.'
  theme.url    = 'http://yorickpeterse.com/'

  theme.templates              = __DIR__
  theme.partials               = __DIR__('partials')
  theme.default_template_group = 'articles'
end
