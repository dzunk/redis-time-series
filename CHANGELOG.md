# Changelog

## Unreleased
* Add Ruby 3.1 to build matrix (#70)
* Add Ruby 3.0 to build matrix (#63)
* Relax Redis version constraint (#62)
* Add TS.REVRANGE, TS.MRANGE, and TS.MREVRANGE commands (#19)
* Update TS.MADD commands to consolidate parsing (#58)

## 0.6.0
* Add CHUNK_SIZE param to CREATE, ADD, INCRBY, DECRBY commands (#53)
* Add duplication policy to TS.CREATE and TS.ADD commands (#51)
* Add support for endless ranges to TS.RANGE (#50)
* Cast label values to integers in Info struct (#49)
* Build against edge upstream in addition to latest stable (#48)

## 0.5.2
* Add chunk_type to info struct (#47)

## 0.5.1
* Update Info struct for RTS 1.4 compatibility (#45)

## 0.5.0
* Fix aggregations for TS.RANGE command (#34)
* Extract client handling into Client module (#32)
* Add `uncompressed` param to TS.ADD, TS.INCRBY, TS.DECRBY (#35)
* Add `Redis::TimeSeries::Rule` object (#38)
* Add [YARD documentation](https://rubydoc.info/gems/redis-time-series) (#40)

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
