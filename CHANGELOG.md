# Changelog

## Unreleased
* Fix aggregations for TS.RANGE command (#34)
* Extract client handling into Client module (#32)
* Add `uncompressed` param to TS.ADD, TS.INCRBY, TS.DECRBY (#35)
* Add `Redis::TimeSeries::Rule` object (#38)

## 0.4.0
* Added [hash-based filter DSL](https://github.com/dzunk/redis-time-series/tree/7173c73588da50614c02f9c89bf2ecef77766a78#filter-dsl)
* Removed `Time#ts_msec` monkey-patch
* Renamed `TimeSeries.queryindex` to `.query_index`
* Added `TS.CREATERULE` and `TS.DELETERULE` commands
* Renamed `InvalidFilters` to `FilterError`

## 0.3.0
* Added `TS.QUERYINDEX` command

## 0.2.0
* Converted `#info` to a struct instead of a hash.
* Added methods on time series for getting info attributes.

## 0.1.1
Fix setting labels on `TS.CREATE` and `TS.ALTER`

## 0.1.0

Basic functionality. Includes commands:
* `TS.CREATE`
* `TS.ALTER`
* `TS.ADD`
* `TS.MADD`
* `TS.INCRBY`
* `TS.DECRBY`
* `TS.RANGE`
* `TS.GET`
* `TS.INFO`
