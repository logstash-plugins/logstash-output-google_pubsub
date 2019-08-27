module LogStash
  module Outputs
    module Pubsub
      # Implements ApiFutureCallback<String>
      class MessageFutureCallback
        include com.google.api.core.ApiFutureCallback

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
