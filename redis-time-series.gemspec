# frozen_string_literal: true
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'redis/time_series/version'

Gem::Specification.new do |spec|
  spec.name          = 'redis-time-series'
  spec.version       = Redis::TimeSeries::VERSION
  spec.authors       = ['Matt Duszynski']
  spec.email         = ['dzunk@hey.com']

  spec.summary       = %q{A Ruby adapter for the RedisTimeSeries module.}
  # spec.description   = %q{TODO: Write a longer description or delete this line.}
  spec.homepage      = 'https://github.com/dzunk/redis-time-series'
  spec.license       = 'MIT'

  if spec.respond_to?(:metadata)
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = spec.homepage
    spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/master/CHANGELOG.md"
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'redis', '>= 3.3'
  spec.add_dependency 'tzinfo', '>= 2.0.6'
  spec.add_dependency 'tzinfo-data', '>= 1.2023.3'

  spec.add_development_dependency 'activesupport', '~> 6.0'
  spec.add_development_dependency 'appraisal', '>= 2.5.0'
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'pry', '~> 0.13'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'simplecov', '< 0.18' # https://github.com/codeclimate/test-reporter/issues/413
end
