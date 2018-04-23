Gem::Specification.new do |s|
  s.name          = 'logstash-output-google_pubsub'
  s.version       = '0.9.10'
  s.licenses      = ['Apache-2.0']
  s.summary       = "Emit output messages to Google Pubsub topic."
  s.description   = "This gem is a Logstash output plugin to be installed on top of the Logstash core pipeline using $LS_HOME/bin/logstash-plugin install gemname. This gem is not a stand-alone program."
  s.homepage      = 'https://cloud.google.com/pubsub/overview'
  s.authors       = ['Nirav Shah']
  s.email         = 'niravshah2705@gmail.com'
  s.require_paths = ['lib']

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT']
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "output" }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core-plugin-api", ">= 1.60", "<= 2.99"
  s.add_runtime_dependency "logstash-codec-plain", "~> 3.0"
  s.add_development_dependency "logstash-devutils", "~> 1.3"
  # Google dependencies
  s.add_runtime_dependency 'google-api-client', '~> 0.8.6', '< 0.9'
end
