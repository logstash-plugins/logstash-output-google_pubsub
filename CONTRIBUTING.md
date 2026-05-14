# Contributing

All contributions are welcome: ideas, patches, documentation, bug reports, complaints, and even something you drew up on a napkin.

Programming is not a required skill. Whatever you've seen about open source and maintainers or community members  saying "send patches or die" - you will not see that here.

It is more important to the community that you are able to contribute.

For more information about contributing, see the [CONTRIBUTING](https://github.com/elastic/logstash/blob/master/CONTRIBUTING.md) file.

## Running the tests

```sh
./gradlew vendor                          # vendor the Java dependencies once
bundle install
bundle exec rspec spec --tag ~integration # unit specs
bundle exec rspec spec --tag integration  # integration specs (in-process gRPC fake)
```

The integration specs spin up an in-process `io.grpc` server that speaks the
Pub/Sub publisher protocol, so no emulator, Docker, or GCP project is required.
They exercise the real `com.google.cloud.pubsub.v1.Publisher` and catch
regressions such as the gRPC class-loading mismatches (see #35).
