# Author: Joseph Lewis III <jlewisiii@google.com>
# Date: 2018-04-12
#
# Copyright 2018 Google LLC
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
# limitations under the License.
require 'logstash/devutils/rspec/spec_helper'
require 'logstash/outputs/pubsub/client'
require 'logstash/codecs/plain'
require 'logstash/event'
require 'java'

describe LogStash::Outputs::Pubsub::Client do
  let(:config) { {
      'project_id' => 'my-project',
      'topic' => 'my-topic',
      'delay_threshold_secs' => 1,
      'message_count_threshold' => 2,
      'request_byte_threshold' => 3,
      'attributes' => {'foo' => 'bar'}
  } }
  let(:sample_event) { LogStash::Event.new({'key'=>'value'}) }

  let(:logger) { double('logger') }
  let(:api_client) { spy('api-client') }
  let(:batch_settings) { double('api-client') }

  subject { LogStash::Outputs::Pubsub::Client.new(nil, nil, batch_settings, logger, api_client) }


  describe '#build_message' do
    it 'creates a Java PubsubMessage' do
      msg = subject.build_message('message-body', {})
      expect(msg.getClass().getName()).to eq('com.google.pubsub.v1.PubsubMessage')
    end

    it 'sets the message body' do
      msg = subject.build_message('message-body', {})
      expect(msg.get_data.to_string_utf8).to eq('message-body')
    end

    it 'adds all attributes' do
      msg = subject.build_message('message-body', {'a'=>'b','c'=>'d'})
      expect(msg.get_attributes_count).to eq(2)
      expect(msg.get_attributes_or_default('a', nil)).to eq('b')
      expect(msg.get_attributes_or_default('c', nil)).to eq('d')
    end

    it 'does not fail with nil attributes' do
      expect{subject.build_message('message-body', nil)}.to_not raise_error
    end
  end

  describe '#build_batch_settings' do
    it 'creates a Java BatchingSettings object' do
      b = LogStash::Outputs::Pubsub::Client.build_batch_settings(1,2,3)

      expect(b.getClass().getName()).to eq('com.google.api.gax.batching.AutoValue_BatchingSettings')
    end

    it 'sets byte threshold correctly' do
      b = LogStash::Outputs::Pubsub::Client.build_batch_settings(1,2,3)

      expect(b.getRequestByteThreshold).to eq(1)
    end

    it 'sets delay correctly' do
      b = LogStash::Outputs::Pubsub::Client.build_batch_settings(1,2,3)

      expect(b.getDelayThreshold().getSeconds()).to eq(2)
    end

    it 'sets count_threshold correctly' do
      b = LogStash::Outputs::Pubsub::Client.build_batch_settings(1,2,3)

      expect(b.getElementCountThreshold()).to eq(3)
    end
  end

  describe '#publish_message' do
    before(:each) do
      allow(com.google.api.core.ApiFutures).to receive(:addCallback)
    end

    it 'builds a message with passed in attributes' do
      allow(subject).to receive(:build_message).and_return(double('message'))
      expect(subject).to receive(:build_message).with('foo', {'a'=>'b'})

      subject.publish_message 'foo', {'a' => 'b'}
    end

    it 'publishes the message' do
      expect(api_client).to receive(:publish)

      subject.publish_message 'foo', {'a' => 'b'}
    end

    it 'creates a callback' do
      expect(com.google.api.core.ApiFutures).to receive(:addCallback)

      subject.publish_message 'foo', {'a' => 'b'}
    end
  end

  describe '#shutdown' do
    it 'calls shutdown on the client' do
      expect(api_client).to receive(:shutdown)

      subject.shutdown
    end
  end
end