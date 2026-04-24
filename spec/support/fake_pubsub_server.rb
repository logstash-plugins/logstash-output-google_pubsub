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
#
# Rationale:
#   - Issue #35 (NoClassDefFoundError in v1.2.1) showed the mock-only specs
#     never exercised the real Publisher code path.
#   - PR #19 (open since 2019) proposed an `emulator_host_port` production
#     config for this same goal; this helper achieves equivalent coverage
#     without changing the plugin's public API, using the existing
#     `client=nil` constructor seam in lib/logstash/outputs/pubsub/client.rb.

require 'java'
require 'logstash-output-google_pubsub_jars'

java_import 'io.grpc.MethodDescriptor'
java_import 'io.grpc.ServerServiceDefinition'
java_import 'io.grpc.inprocess.InProcessServerBuilder'
java_import 'io.grpc.inprocess.InProcessChannelBuilder'
java_import 'io.grpc.protobuf.ProtoUtils'
java_import 'io.grpc.stub.ServerCalls'

class FakePubsubServer
  # Implements io.grpc.stub.ServerCalls.UnaryMethod for the Publish RPC.
  # Runs on a gRPC server thread — uses concurrent collections and a latch
  # so assertions on the main thread can await a known request count.
  class PublishHandler
    include Java::IoGrpcStub::ServerCalls::UnaryMethod

    attr_reader :requests, :latch

    def initialize(expected_requests)
      @requests = java.util.concurrent.ConcurrentLinkedQueue.new
      @latch    = java.util.concurrent.CountDownLatch.new(expected_requests)
    end

    def invoke(request, response_observer)
      @requests.add(request)
      ids = (0...request.get_messages_count).map { |i| "fake-id-#{@requests.size}-#{i}" }
      response = com.google.pubsub.v1.PublishResponse.newBuilder.addAllMessageIds(ids).build
      response_observer.onNext(response)
      response_observer.onCompleted
      @latch.count_down
    end
  end

  PUBLISH_METHOD = MethodDescriptor.newBuilder
    .setType(MethodDescriptor::MethodType::UNARY)
    .setFullMethodName('google.pubsub.v1.Publisher/Publish')
    .setRequestMarshaller(ProtoUtils.marshaller(com.google.pubsub.v1.PublishRequest.getDefaultInstance))
    .setResponseMarshaller(ProtoUtils.marshaller(com.google.pubsub.v1.PublishResponse.getDefaultInstance))
    .build

  def initialize(expected_requests: 1)
    @name    = "fake-pubsub-#{java.util.UUID.randomUUID}"
    @handler = PublishHandler.new(expected_requests)

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
    @handler.requests.to_a
  end

  def await_requests(seconds = 5)
    @handler.latch.await(seconds, java.util.concurrent.TimeUnit::SECONDS)
  end

  def stop
    @server&.shutdown&.awaitTermination(5, java.util.concurrent.TimeUnit::SECONDS)
  end
end
