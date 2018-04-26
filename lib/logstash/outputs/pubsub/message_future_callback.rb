# Author: Joseph Lewis III <jlewisiii@google.com>
# Date: 2018-04-12
#
# Copyright 2018 Google Inc.
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
module LogStash
  module Outputs
    module Pubsub
      # Implements ApiFutureCallback<String>
      class MessageFutureCallback
        def initialize(message_body, logger)
          @message_body = message_body
          @logger = logger
        end

        # Implements public void onSuccess(String messageId)
        def on_success(message_id)
          @logger.debug("Published #{@message_body} with id: #{message_id}")
        end

        # Implements public void onFailure(Throwable t)
        def on_failure(throwable)
          @logger.error("Failed to send message.", message: @message_body, error: throwable.getMessage)
        end
      end
    end
  end
end
