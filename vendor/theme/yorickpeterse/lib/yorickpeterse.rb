Zen::Theme.add do |theme|
  theme.name   = 'yorickpeterse'
  theme.author = 'Yorick Peterse'
  theme.about  = 'Theme for my personal website, inspired by bin/man.'
  theme.url    = 'http://yorickpeterse.com/'

  theme.template_dir = __DIR__('yorickpeterse/templates')
  theme.partial_dir  = __DIR__('yorickpeterse/templates/partials')
  theme.public_dir   = __DIR__('yorickpeterse/public')
end
