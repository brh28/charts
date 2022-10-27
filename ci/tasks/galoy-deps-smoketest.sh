#!/bin/bash

set -eu

source smoketest-settings/helpers.sh

kafka_broker_host=`setting "kafka_broker_endpoint"`
kafka_broker_port=`setting "kafka_broker_port"`
kafka_topic=`setting "kafka_topic"`

set +e

msg="kafka message"
echo $msg | kafkacat -P -b $kafka_broker_host:$kafka_broker_port -t $kafka_topic
consumed_message=$(kafkacat -C -b $kafka_broker_host:$kafka_broker_port -t $kafka_topic)
if [[ "$consumed_message" == "$msg" ]]; then exit 0; else echo "Smoke test failed" && exit 1; fi;

set -e
