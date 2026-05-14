# encoding: utf-8
#
# In-process gRPC fake of the Pub/Sub Publisher service for integration tests.
#
# Uses io.grpc.inprocess (a transitive dep via libraries-bom since v1.2.2) so
# no external process, port, emulator, or Docker is needed. The service is
# assembled from MethodDescriptor + ProtoUtils.marshaller rather than the
# generated PublisherGrpc stub, because only the protobuf message types
# (proto-google-cloud-pubsub-v1) and not the grpc stub jar
# (grpc-google-cloud-pubsub-v1) are on the plugin's runtime classpath.

require 'java'
require 'logstash-output-google_pubsub_jars'

java_import 'io.grpc.MethodDescriptor'
java_import 'io.grpc.ServerServiceDefinition'
java_import 'io.grpc.inprocess.InProcessServerBuilder'
java_import 'io.grpc.inprocess.InProcessChannelBuilder'
java_import 'io.grpc.protobuf.ProtoUtils'
java_import 'io.grpc.stub.ServerCalls'

class FakePubsubServer
  class PublishHandler
    include Java::IoGrpcStub::ServerCalls::UnaryMethod

    attr_reader :received

    def initialize
      @received = java.util.concurrent.ConcurrentLinkedQueue.new
      @ready    = java.util.concurrent.LinkedBlockingQueue.new
      @counter  = java.util.concurrent.atomic.AtomicLong.new(0)
    end

    def invoke(request, response_observer)
      @received.add(request)
      begin
        n   = @counter.incrementAndGet
        ids = (0...request.get_messages_count).map { |i| "fake-id-#{n}-#{i}" }
        response = com.google.pubsub.v1.PublishResponse.newBuilder.addAllMessageIds(ids).build
        response_observer.onNext(response)
        response_observer.onCompleted
      ensure
        @ready.put(request)
      end
    end

    def poll_ready(timeout_s)
      @ready.poll(timeout_s, java.util.concurrent.TimeUnit::SECONDS)
    end
  end

  PUBLISH_METHOD = MethodDescriptor.newBuilder
    .setType(MethodDescriptor::MethodType::UNARY)
    .setFullMethodName('google.pubsub.v1.Publisher/Publish')
    .setRequestMarshaller(ProtoUtils.marshaller(com.google.pubsub.v1.PublishRequest.getDefaultInstance))
    .setResponseMarshaller(ProtoUtils.marshaller(com.google.pubsub.v1.PublishResponse.getDefaultInstance))
    .build

  def initialize
    @name    = "fake-pubsub-#{java.util.UUID.randomUUID}"
    @handler = PublishHandler.new

    service = ServerServiceDefinition.builder('google.pubsub.v1.Publisher')
                .addMethod(PUBLISH_METHOD, ServerCalls.asyncUnaryCall(@handler))
                .build

    @server = InProcessServerBuilder.forName(@name)
                .directExecutor
                .addService(service)
                .build
                .start
  end

  # Builds a real com.google.cloud.pubsub.v1.Publisher wired to the fake via
  # an in-JVM channel. Inject via Pubsub::Client.new(..., client: publisher).
  def build_publisher(topic_name, batch_settings)
    channel = InProcessChannelBuilder.forName(@name)
                .directExecutor
                .usePlaintext
                .build
    provider = com.google.api.gax.rpc.FixedTransportChannelProvider.create(
      com.google.api.gax.grpc.GrpcTransportChannel.create(channel)
    )
    com.google.cloud.pubsub.v1.Publisher.newBuilder(topic_name)
      .setChannelProvider(provider)
      .setCredentialsProvider(com.google.api.gax.core.NoCredentialsProvider.create)
      .setBatchingSettings(batch_settings)
      .build
  end

  def requests
    @handler.received.to_a
  end

  # Blocks until the next RPC arrives, or returns nil after timeout.
  def await_request(timeout_s = 5)
    @handler.poll_ready(timeout_s)
  end

  def stop
    @server&.shutdown&.awaitTermination(5, java.util.concurrent.TimeUnit::SECONDS)
  end
end
