# docker-compose-influx-grafana
docker-compose for icinga related influx/grafana setup

setting up:
  * influx
    * static admin token
    * bucket for icinga
    * bucket for telegraf
  * grafana
    * datasource for icinga bucket (flux & influxQL)
    * dashboards from https://github.com/Mikesch-mp/icingaweb2-module-grafana 
      * changed in some details
  * telegraf
    * writing cpu, disk, mem to telegraf bucket

## Start/Stop Environment

```bash
docker-compose -p influx-playground up -d

docker-compose -p influx-playground down -v
```

## Used Images:
  * https://hub.docker.com/r/grafana/grafana-image-renderer/tags
  * https://hub.docker.com/r/grafana/grafana/tags
  * https://hub.docker.com/_/influxdb/tags

# Analyse:

Explore the schema and cardinality of a bucket
 
Example:
```bash
./analyze_influx_bucket.sh telegraf | jq
[
  {
    "measurement": "cpu",
    "field_count": 11,
    "Cardinality": 21,
    "tag_count": 2,
    "tags": [
      {
        "tag": "cpu",
        "value_count": 21
      },
      {
        "tag": "host",
        "value_count": 1
      }
    ]
  },
...
```

## jq examples

 - Top 5 Cardinality
   - `jq 'sort_by(-.Cardinality) | .[:5] | {measurement: .[].measurement, Cardinality: .[].Cardinality}' data.json`
 - Measurement + Cardinality
   - `jq sort_by(-.Cardinality) | .[:5] | map({measurement, Cardinality})' data.json`
 - Top 5 Field Counts
   - `jq 'sort_by(-.field_count) | .[:5] | map({measurement, field_count})' data.json`


