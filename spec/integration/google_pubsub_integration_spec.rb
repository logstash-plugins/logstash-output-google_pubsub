# encoding: utf-8
require 'logstash/devutils/rspec/spec_helper'
require 'logstash/outputs/google_pubsub'
require 'logstash/outputs/pubsub/client'
require 'logstash/event'
require_relative '../support/fake_pubsub_server'

# Integration specs. Exercise the real com.google.cloud.pubsub.v1.Publisher
# against an in-process gRPC fake. Complement, do not replace, the unit
# specs in spec/outputs/ which use doubles.
#
# Run with: bundle exec rspec spec/integration --tag integration
describe 'GooglePubsub output integration', :integration do
  let(:topic)   { 'projects/test-project/topics/test-topic' }
  let(:config)  { {
      'project_id'              => 'test-project',
      'topic'                   => 'test-topic',
      'delay_threshold_secs'    => 1,
      'message_count_threshold' => 100,
      'request_byte_threshold'  => 1_000_000,
      'attributes'              => { 'env' => 'test' }
  } }

  # Send messages out as soon as one event is queued — keeps tests fast
  # and deterministic without relying on the delay threshold timer.
  let(:flush_now_settings) {
    LogStash::Outputs::Pubsub::Client.build_batch_settings(1_000_000, 1, 1)
  }

  let!(:fake)      { FakePubsubServer.new(expected_requests: 1) }
  let(:publisher)  { fake.build_publisher(topic, flush_now_settings) }
  let(:logger)     { double('logger').as_null_object }
  let(:client)     { LogStash::Outputs::Pubsub::Client.new(nil, topic, flush_now_settings, logger, publisher) }

  # Hand-assemble the output with the injected client so we exercise the
  # real multi_receive / codec pipeline but skip credentials loading.
  subject(:output) do
    out = LogStash::Outputs::GooglePubsub.new(config)
    out.instance_variable_set(:@pubsub, client)
    out.instance_variable_set(:@logger, logger)
    out.instance_variable_set(:@codec, LogStash::Plugin.lookup('codec', 'json').new)
    out.codec.on_event { |event, data| out.instance_variable_get(:@pubsub).publish_message(data, out.attributes) }
    out
  end

  after(:each) { fake.stop }

  def published_messages
    fake.requests.flat_map { |req| req.get_messages_list.to_a }
  end

  it 'publishes an event end-to-end through the real Publisher' do
    output.multi_receive([LogStash::Event.new('key' => 'value')])

    expect(fake.await_requests).to be(true), 'timed out waiting for publish request'
    msgs = published_messages
    expect(msgs.size).to eq(1)
    expect(msgs.first.get_data.to_string_utf8).to include('"key":"value"')
  end

  it 'passes per-event attributes through to the wire (regression for issue #20)' do
    output.multi_receive([LogStash::Event.new('key' => 'value')])

    expect(fake.await_requests).to be(true)
    attrs = published_messages.first.get_attributes_map
    expect(attrs.get('env')).to eq('test')
  end

  it 'drains pending events on shutdown (regression for issue #26)' do
    # Batch threshold high enough that nothing flushes naturally within
    # the test window — only shutdown() can get these messages through.
    lingering = LogStash::Outputs::Pubsub::Client.build_batch_settings(1_000_000, 60, 10)
    fake_drain = FakePubsubServer.new(expected_requests: 1)
    drain_pub  = fake_drain.build_publisher(topic, lingering)
    drain_cli  = LogStash::Outputs::Pubsub::Client.new(nil, topic, lingering, logger, drain_pub)

    3.times { |i| drain_cli.publish_message({ 'n' => i }.to_json, {}) }
    drain_cli.shutdown

    begin
      expect(fake_drain.await_requests(10)).to be(true), 'shutdown did not flush pending messages'
      msgs = fake_drain.requests.flat_map { |r| r.get_messages_list.to_a }
      expect(msgs.size).to eq(3)
    ensure
      fake_drain.stop
    end
  end
end
