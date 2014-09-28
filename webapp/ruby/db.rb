require 'redis'
require 'json'

class RedisWrapper
  class << self
    def client
      @client ||= ::Redis.new
    end
  end

  def client
    self.class.client
  end

  def get_user_by_id(id)
    parse(client.hget("user-id", id))
  end

  def get_user_by_login(login)
    res = client.hget("userid-login", login)
    res ? get_user_by_login(res) : nil
  end

  def parse(res)
    res ? JSON.parse(res) : nil
  end

  def set_user(user)
    set_users([user])
  end

  def set_users(users)
    ids = users.map { |user| user['id'] }
    logins = users.map { |user| user['login'] }
    values = users.map(&:to_json)
    client.hmset("user-id", *(ids.zip(values).flatten))
    client.hmset("userid-login", *(logins.zip(ids).flatten))
  end
end

class DBWrapper
  attr_reader :client
  def initialize
    @client = Thread.current[:isu4_db] ||= Mysql2::Client.new(
      host: ENV['ISU4_DB_HOST'] || 'localhost',
      port: ENV['ISU4_DB_PORT'] ? ENV['ISU4_DB_PORT'].to_i : nil,
      username: ENV['ISU4_DB_USER'] || 'root',
      password: ENV['ISU4_DB_PASSWORD'],
      database: ENV['ISU4_DB_NAME'] || 'isu4_qualifier',
      reconnect: true,
    )
  end
end
