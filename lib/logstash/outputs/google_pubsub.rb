require 'logstash/outputs/base'
require 'logstash/namespace'
require 'logstash/outputs/pubsub/client'

# A Logstash plugin to upload log events to https://cloud.google.com/pubsub/[Google Cloud Pubsub].
class LogStash::Outputs::GooglePubsub < LogStash::Outputs::Base
  config_name 'google_pubsub'

  concurrency :shared

  # Google Cloud Project ID (name, not number)
  config :project_id, validate: :string, required: true

  # Google Cloud Emulator Host/Port
  config :emulator_host_port, validate: :string, required: false

  # Google Cloud Pub/Sub Topic, expected to exist before the plugin starts
  config :topic, validate: :string, required: true

  # A full path to the JSON key file, if empty it's assumed Application Default Credentials
  # will be used.
  config :json_key_file, validate: :path, required: false

  # Send the batch once this delay has passed, from the time the first message
  # is queued. (> 0, default: 5)
  config :delay_threshold_secs, validate: :number, default: 5

  # Once this many messages are queued, send all the messages in a single call, < 1000
  config :message_count_threshold, validate: :number, default: 100

  # Once the number of bytes in the batched request reaches this threshold,
  # send all of the messages in a single call, even if neither the delay or
  # message count thresholds have been exceeded yet.
  config :request_byte_threshold, validate: :bytes, default: 1_000_000

  # Attributes to add to the message in key: value formats.
  config :attributes, validate: :hash, default: {}

  # By default, we serialize messages with JSON.
  default :codec, 'json'

  def register
    @logger.info("Registering Google PubSub Output plugin: #{full_topic}")

    batch_settings = LogStash::Outputs::Pubsub::Client.build_batch_settings(
      @request_byte_threshold,
      @delay_threshold_secs,
      @message_count_threshold
    )

    @pubsub = LogStash::Outputs::Pubsub::Client.new(
        @json_key_file,
        @emulator_host_port,
        full_topic,
        batch_settings,
        @logger
    )

    # Test that the attributes don't cause errors when they're set.
    begin
      @pubsub.build_message('', @attributes)
    rescue TypeError => e
      message = 'Make sure the attributes are string:string pairs'
      @logger.error(message, error: e, attributes: @attributes)
      raise message
    end
  end

  def multi_receive_encoded(events_and_encoded)
    events_and_encoded.each do |event, encoded|
      @logger.debug("Sending message #{encoded}")

      @pubsub.publish_message(encoded, @attributes)
    end
  end

  def stop
    @pubsub.shutdown
  end

  def full_topic
    "projects/#{@project_id}/topics/#{@topic}"
  end
end
