Zen::Theme.add do |theme|
  theme.name   = :yorickpeterse
  theme.author = 'Yorick Peterse'
  theme.about  = 'Theme for my personal website.'
  theme.url    = 'http://yorickpeterse.com/'

  theme.templates              = __DIR__
  theme.partials               = __DIR__('partials')
  theme.default_template_group = 'articles'

  theme.env.asset = Ramaze::Asset::Environment.new(
    :cache_path => __DIR__('../public/minified'),
    :minify     => Ramaze.options.mode == :live
  )

  theme.env.asset.serve(
  :css,
  [
    'yorickpeterse/css/reset',
    'yorickpeterse/css/grid',
    'yorickpeterse/css/github',
    'yorickpeterse/css/style',
  ],
  :name => 'yorickpeterse'
)
end

Zen::Event.listen(:post_start) do
  Zen::Theme[:yorickpeterse].env.asset.build(:css)
end
