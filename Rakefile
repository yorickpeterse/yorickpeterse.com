require 'rake/clean'

CLEAN.include('build')

Dir.glob(File.expand_path('../task/*.rake', __FILE__)) { |task| import task }

task default: :build
