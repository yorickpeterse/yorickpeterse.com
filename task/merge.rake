desc 'Merges all CSS files'
task :merge do
  css      = File.expand_path('../../output/css/', __FILE__)
  minified = File.join(css, 'minified.css')
  files    = Dir.glob(File.join(css, '{reset.css,github.css,style.css}'))

  File.unlink(minified) if File.file?(minified)

  abort "No CSS files found" if files.empty?

  minified = File.open(minified, 'w')

  files.each do |file|
    File.open(file, 'r') do |handle|
      handle.lines { |line| minified.write(line) }
    end
  end

  minified.close
end
