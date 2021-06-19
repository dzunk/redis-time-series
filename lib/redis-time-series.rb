require 'bigdecimal'
require 'forwardable'
require 'ext/time_msec'

require 'redis/time_series/client'
require 'redis/time_series/errors'
require 'redis/time_series/aggregation'
require 'redis/time_series/duplicate_policy'
require 'redis/time_series/filters'
require 'redis/time_series/multi'
require 'redis/time_series/rule'
require 'redis/time_series/info'
require 'redis/time_series/sample'
require 'redis/time_series/samples'
require 'redis/time_series'

class RedisTimeSeries; end
