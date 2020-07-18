require 'bigdecimal'
require 'forwardable'
require 'time/msec'
require 'redis/time_series/filters'
require 'redis/time_series/info'
require 'redis/time_series/sample'
require 'redis/time_series'

class RedisTimeSeries
  VERSION = '0.3.0'
end
