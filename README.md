# docker-compose-influx-grafana
docker-compose for icinga related influx/grafana setup

setting up:
  * influx
    * static admin token
    * bucket for icinga
  * grafana
    * datasource for icinga bucket (flux & influxQL)
    * dashboards from https://github.com/Mikesch-mp/icingaweb2-module-grafana 
      * changed in some details

## Start/Stop Environment

```bash
docker-compose -p influx-playground up -d

docker-compose -p influx-playground down -v
```
