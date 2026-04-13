## 1.2.2
 - Fixed no class found issues due to gRPC dependency mismatch caused by re-packaging [#36](https://github.com/logstash-plugins/logstash-output-google_pubsub/issues/36)
 - Adopted Google Cloud BOM (`libraries-bom:26.79.0`) for dependency management, replacing manual version constraints

## 1.2.1
 - Re-packaging the plugin [#33](https://github.com/logstash-plugins/logstash-output-google_pubsub/pull/33)
 - Removed `jar-dependencies` dependency [#31](https://github.com/logstash-plugins/logstash-output-google_pubsub/pull/31)

## 1.2.0
 - Updated Google PubSub client library [#29](https://github.com/logstash-plugins/logstash-output-google_pubsub/pull/29)

## 1.1.0
 - Updated Google PubSub client library, needs Logstash `>= 8.2.0` to run [#27](https://github.com/logstash-plugins/logstash-output-google_pubsub/pull/27)

## 1.0.1
  - Fixed invalid link in documentation [#10](https://github.com/logstash-plugins/logstash-output-google_pubsub/pull/10)
  
## 1.0.0
  - Initial implementation
