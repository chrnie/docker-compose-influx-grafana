#!/bin/bash
# Usage: ./analyze_influx.sh <BUCKET> <ORG> <URL> <TOKEN>

BUCKET=$1
ORG=$2
URL=$3
TOKEN=$4

run_query () {
  NAME=$1
  QUERY=$2
  echo -e "\n--- $NAME ---"
  influx query --org "$ORG" --host "$URL" --token "$TOKEN" "$QUERY"
}

# Measurements
MEASUREMENTS="import \"influxdata/influxdb/schema\"
schema.measurements(bucket: \"$BUCKET\")"

# Fields per Measurement
FIELDS="import \"influxdata/influxdb/schema\"
schema.measurements(bucket: \"$BUCKET\")
  |> map(fn: (r) => ({
      measurement: r._value,
      field_count: schema.measurementFieldKeys(bucket: \"$BUCKET\", measurement: r._value) |> count()
  }))"

# Tags per Measurement
TAGS="import \"influxdata/influxdb/schema\"
schema.measurements(bucket: \"$BUCKET\")
  |> map(fn: (r) => ({
      measurement: r._value,
      tag_count: schema.measurementTagKeys(bucket: \"$BUCKET\", measurement: r._value) |> count()
  }))"

# --- Run Flux Queries ---
run_query "Measurements" "$MEASUREMENTS"
run_query "Fields per Measurement" "$FIELDS"
run_query "Tags per Measurement" "$TAGS"

# --- Cardinality (CLI statt Flux) ---
echo -e "\n--- Bucket Cardinality ---"
influx bucket cardinality --bucket "$BUCKET" --org "$ORG" --host "$URL" --token "$TOKEN"

echo -e "\n--- Measurement Cardinality ---"
influx bucket cardinality --bucket "$BUCKET" --org "$ORG" --host "$URL" --token "$TOKEN" --series

