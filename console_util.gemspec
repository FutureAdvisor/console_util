# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "console_util/version"

Gem::Specification.new do |s|
  s.name        = "console_util"
  s.version     = ConsoleUtil::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["FutureAdvisor"]
  s.email       = ["core.platform@futureadvisor.com"]
  s.homepage    = %q{http://github.com/FutureAdvisor/console_util}
  s.summary     = %q{Contains various utilities for working in the Rails console.}
  s.description = %q{Contains various utilities for working in the Rails console.}
  s.license     = 'MIT'

  s.add_dependency('rails', '>= 2.1.0')

  s.rubyforge_project = "console_util"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
