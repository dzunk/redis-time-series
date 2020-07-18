require 'bigdecimal'
require 'forwardable'
require 'ext/time_msec'
require 'redis/time_series/errors'
require 'redis/time_series/aggregation'
require 'redis/time_series/filters'
require 'redis/time_series/info'
require 'redis/time_series/sample'
require 'redis/time_series'

class RedisTimeSeries
  VERSION = '0.4.0'
end
