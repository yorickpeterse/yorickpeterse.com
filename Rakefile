require 'rake/clean'

tmp = File.expand_path('../tmp', __FILE__)

CLEAN.include(tmp, 'output', 'crash.log')

Dir.glob(File.expand_path('../task/*.rake', __FILE__)) { |task| import task }
