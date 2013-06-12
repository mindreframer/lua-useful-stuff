# -*- encoding: utf-8 -*-
root = File.expand_path('../', __FILE__)
lib = "#{root}/lib"

$:.unshift lib unless $:.include?(lib)

Gem::Specification.new do |s|
  s.name        = "accelerator"
  s.version     = '0.1.1'
  s.platform    = Gem::Platform::RUBY
  s.authors     = [ "Winton Welsh" ]
  s.email       = [ "mail@wintoni.us" ]
  s.homepage    = "http://github.com/winton/nginx-accelerator"
  s.summary     = %q{Drop-in page caching using nginx, lua, and memcached}
  s.description = %q{Drop-in page caching using nginx, lua, and memcached.}

  s.executables = `cd #{root} && git ls-files bin/*`.split("\n").collect { |f| File.basename(f) }
  s.files = `cd #{root} && git ls-files`.split("\n")
  s.require_paths = %w(lib)
  s.test_files = `cd #{root} && git ls-files -- {features,test,spec}/*`.split("\n")

  s.add_dependency "memcached", "~> 1.5.0"
  s.add_development_dependency "rspec", "~> 2.0"
  s.add_development_dependency "guard"
  s.add_development_dependency "guard-rspec"
  s.add_development_dependency "rb-fsevent"
end