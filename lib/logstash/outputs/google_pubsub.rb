# encoding: utf-8

# Author: Eric Johnson <erjohnso@google.com>
# Author: Nirav Shah <niravshah2705@gmail.com>
# Date: 2018-03-31
#
# Copyright 2017 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and

## Sample Configuration file
## output {
## 	google_pubsub {
## # Your GCP project id (name)
## 		project_id => "premium-poc"
## # The topic name below is currently hard-coded in the plugin. You
## # must first create this topic by hand before attempting to output
## # messages to Google Pubsub.
## 		topic => "pubsub-output-plugin-topic"
## # Dynamic topic also supported based on the field in message or logstash tags
##              topic => "%{topic}"

## # If defined Only content of field passed as message. exclude_fields & include_fields ignored
## 		include_field =>  "message"  

## # Exclude list takes precedence over include list
## 		exclude_fields => [ "@version" , "filename" , "tags" ]

## # Only mentioned field passed in json format with key
## 		include_fields => [ "message" ]

## # Set number of retries to avoid loss due to transient issues.
## # Setting value to 0 does not retry. Default value set as 1
##		retry => 2
## # If you are running logstash within GCE, it will use
## # Application Default Credentials and use GCE's metadata
## # service to fetch tokens.  However, if you are running logstash
## # outside of GCE, you will need to specify the service account's
## # JSON key file below.
## #		json_key_file => "/home/nirav/Downloads/Premium-POC-5837fe4cfb8f.json"
## #		}
## }

# limitations under the License.
require "logstash/outputs/base"
require "logstash/namespace"
require "google/api_client"

# An google_pubsub output that does nothing.
class LogStash::Outputs::GooglePubsub < LogStash::Outputs::Base
  config_name "google_pubsub"

  concurrency :single

  # Google Cloud Project ID (name, not number)
  config :project_id, :validate => :string, :required => true

  # Google Cloud Pub/Sub Topic. Must create topic manually.
  config :topic, :validate => :string, :required => true
  # TODO: allow users to set Pubsub 'attributes' that will be set for messages
  # see https://cloud.google.com/pubsub/docs/reference/rest/v1/PubsubMessage
  # These _could_ also be added as event fields in addition to adding them to
  # the pubsub message body
  # config :attributes...
 #  config :use_event_fields_for_data_points, :validate => :boolean, :default => false
   config :exclude_fields, :validate => :array, :default => [ ] #"@timestamp", "@version", "sequence", "message", "type"]  
   config :include_fields, :validate => :array, :default => [ ] #"@timestamp", "@version", "sequence", "message", "type"]  
   config :include_field, :validate => :string #"@timestamp", "@version", "sequence", "message", "type"]  

 # config will retry failed post with exponential backoff method. Default set to 1
   config :retry, :validate => :number, :default => 1 

  # If logstash is running within Google Compute Engine, the plugin will use
  # GCE's Application Default Credentials. Outside of GCE, you will need to
  # specify a Service Account JSON key file.
  config :json_key_file, :validate => :path, :required => false

  # If undefined, Logstash will complain, even if codec is unused.
  default :codec, "plain"

  private
  def request(options)
    begin
      @logger.debug("Sending an API request")
      result = @client.execute(options)
    rescue ArgumentError => e
      @logger.debug("Authorizing...")
      @client.authorization.fetch_access_token!
      @logger.debug("...authorized")
      request(options)
    rescue Faraday::TimeoutError => e
      @logger.debug("Request timeout, re-trying request")
      request(options)
    end
  end # def request

  public
  def register
#    @logger.debug("Registering Google PubSub Output plugin: project_id=#{@project_id}, topic=#{@topic}")
#    @topic = "projects/#{@project_id}/topics/#{@topic}"

    # TODO(erjohnso): read UA data from the gemspec
    @client = Google::APIClient.new(
      :application_name => 'logstash-output-google_pubsub',
      :application_version => '0.9.10'
    )

    # Initialize the pubsub API client
    @pubsub = @client.discovered_api('pubsub', 'v1')

    # Handle various kinds of auth (JSON or Application Default Creds)
    # NOTE: Cannot use 'googleauth' gem since there are dependency conflicts
    #       - googleauth ~> 0.5 requires mime-data-types that requires ruby2
    #       - googleauth ~> 0.3 requires multi_json 1.11.0 that conflicts
    #         with logstash-2.3.2's multi_json 1.11.3
    if @json_key_file
      @logger.debug("Authorizing with JSON key file: #{@json_key_file}")
      file_path = File.expand_path(@json_key_file)
      key_json = File.open(file_path, "r", &:read)
      key_json = JSON.parse(key_json)
      unless key_json.key?("client_email") || key_json.key?("private_key")
        raise Google::APIClient::ClientError, "Invalid JSON credentials data."
      end
      signing_key = ::Google::APIClient::KeyUtils.load_from_pem(key_json["private_key"], "notasecret")
      @client.authorization = Signet::OAuth2::Client.new(
        :audience => "https://accounts.google.com/o/oauth2/token",
        :auth_provider_x509_cert_url => "https://www.googleapis.com/oauth2/v1/certs",
        :client_x509_cert_url => "https://www.googleapis.com/robot/v1/metadata/x509/#{key_json['client_email']}",
        :issuer => "#{key_json['client_email']}",
        :scope => %w(https://www.googleapis.com/auth/cloud-platform),
        :signing_key => signing_key,
        :token_credential_uri => "https://accounts.google.com/o/oauth2/token"
      )
      @logger.debug("Client authorizataion with JSON key ready")
    else
      # Assume we're running in GCE and can use metadata tokens, if the host
      # GCE instance was not created with the PubSub scope, then the plugin
      # will not be authorized to read from pubsub.
      @logger.debug("Authorizing with application default credentials")
      @client.authorization = :google_app_default
    end # if @json_key_file...
  end # def register

  public
  def receive(event)
    # Google Pubsub only accepts base64 encoded messages. The message data
    # should be JSON which we can get from the event object using `to_json`
    # TODO add :attributes to the pubsub_message and _maybe_ event fields

     json_data =  JSON.parse(event.to_json)


        localtopic = @topic.start_with?('%')? json_data["#{@topic[/{(.+)}/,1]}"] :  @topic
	@logger.debug("==============================================================") 
        @logger.debug("Using Google PubSub Output plugin topic: project_id=#{@project_id}, topic=#{localtopic}")
	@logger.debug("==============================================================") 
	localtopic = "projects/#{@project_id}/topics/#{localtopic}"
    
    if @include_field
	 pubsub_message = {
        :data => Base64.urlsafe_encode64(json_data["#{@include_field}"])
      }
	@logger.debug(json_data["#{@include_field}"])
    else
    @exclude_fields.each { |field| json_data.delete(field) }
  
    @logger.debug(json_data.to_json)

      pubsub_message = {
        :data => Base64.urlsafe_encode64(@include_fields.empty? ? json_data.to_json : json_data.select {|k,_| include_fields.include?(k)}.to_json)
      }
    end
    # TODO: may need to look at batch messages vs one-at-a-time
	
	attempt=1
	while true
	    result = request(
        	:api_method => @pubsub.projects.topics.publish,
	        :parameters => {'topic' => localtopic},
        	:body_object => {
	            :messages => [pubsub_message]
        	}
    		)
	    if !result.error?
	      response_body = JSON.parse(result.body)
	      if response_body.key?("messageIds")
	        ids = response_body["messageIds"]
	        @logger.info("Message published. Returned messageIds: '#{ids}'")
		break
	      end
	    else
		if attempt<=@retry
			sleepfor = sleep_for_attempt(attempt)
			@logger.info("Retrying .. waiting for #{sleepfor} seconds .. attempt #{attempt}")
		else
		      @logger.error("Error publishing message '#{event.get("message")}' to topic '#{localtopic}'")
		      @logger.error("http status #{result.status}: #{result.error_message}")
		      break
		end
	    end
 	    sleep(sleepfor)
	    attempt=attempt+1
	end # while
    return
  end # def event
  def sleep_for_attempt(attempt)
    sleep_for = attempt**2
    sleep_for = sleep_for <= 10 ? sleep_for : 10
    return sleep_for + rand(1..sleep_for)/2 
  end

end # class LogStash::Outputs::GooglePubsub
 
