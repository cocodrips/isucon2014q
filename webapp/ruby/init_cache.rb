require_relative 'db'
require 'mysql2-cs-bind'

redis = RedisWrapper.new
db = DBWrapper.new.client

db.query('SELECT * FROM users').each_slice(300) { |users| redis.set_users(users) }

