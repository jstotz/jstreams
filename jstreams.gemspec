if ENV['DOCKER_BUILD']
  version = '0.0.0'
else
  lib = File.expand_path('../lib', __FILE__)
  $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
  require 'jstreams/version'
  version = Jstreams::VERSION
end

Gem::Specification.new do |spec|
  spec.name = 'jstreams'
  spec.version = version
  spec.authors = ['Jay Stotz']
  spec.email = %w[jason.stotz@gmail.com]

  spec.summary =
    'A distributed pub/sub messaging system for Ruby based on Redis Streams'
  spec.homepage = 'https://github.com/jstotz/jstreams'
  spec.license = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"

    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/jstotz/jstreams'
    spec.metadata['changelog_uri'] =
      'https://github.com/jstotz/jstreams/blob/master/CHANGELOG.md'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
            'public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files =
    Dir.chdir(File.expand_path('..', __FILE__)) do
      unless ENV['DOCKER_BUILD']
        `git ls-files -z`.split("\x0").reject do |f|
          f.match(%r{^(test|spec|features)/})
        end
      end
    end

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = %w[lib]

  spec.add_dependency 'redis', '>= 4.1.0'
  spec.add_dependency 'activesupport'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
