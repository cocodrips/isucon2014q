require 'sinatra/base'
require 'digest/sha2'
require 'mysql2-cs-bind'
require 'rack-flash'
require 'json'
require_relative 'db'

module Isucon4
  class App < Sinatra::Base
    use Rack::Session::Cookie, secret: ENV['ISU4_SESSION_SECRET'] || 'shirokane'
    use Rack::Flash
    set :public_folder, File.expand_path('../../public', __FILE__)

    helpers do
      def redis
        @redis ||= RedisWrapper.new
      end

      def config
        @config ||= {
          user_lock_threshold: (ENV['ISU4_USER_LOCK_THRESHOLD'] || 3).to_i,
          ip_ban_threshold: (ENV['ISU4_IP_BAN_THRESHOLD'] || 10).to_i,
        }
      end

      def db
        @db ||= DBWrapper.new.client
      end

      def calculate_password_hash(password, salt)
        Digest::SHA256.hexdigest "#{password}:#{salt}"
      end

      def login_log(succeeded, login, user_id = nil)
        db.xquery("INSERT INTO login_log" \
                  " (`created_at`, `user_id`, `login`, `ip`, `succeeded`)" \
                  " VALUES (?,?,?,?,?)",
                 Time.now, user_id, login, request.ip, succeeded ? 1 : 0)
      end

      def user_locked?(user)
        return nil unless user
        log = db.xquery("SELECT COUNT(1) AS failures FROM login_log WHERE user_id = ? AND id > IFNULL((select id from login_log where user_id = ? AND succeeded = 1 ORDER BY id DESC LIMIT 1), 0);", user['id'], user['id']).first

        config[:user_lock_threshold] <= log['failures']
      end

      def ip_banned?
        log = db.xquery("SELECT COUNT(1) AS failures FROM login_log WHERE ip = ? AND id > IFNULL((select id from login_log where ip = ? AND succeeded = 1 ORDER BY id DESC LIMIT 1), 0);", request.ip, request.ip).first

        config[:ip_ban_threshold] <= log['failures']
      end

      def attempt_login(login, password)
        user = redis.get_user_by_login(login) || db.xquery('SELECT * FROM users WHERE login = ?', login).first

        if ip_banned?
          login_log(false, login, user ? user['id'] : nil)
          return [nil, :banned]
        end

        if user_locked?(user)
          login_log(false, login, user['id'])
          return [nil, :locked]
        end

        if user && Digest::SHA256.hexdigest("#{password}:#{user['salt']}") == user['password_hash']
          login_log(true, login, user['id'])
          [user, nil]
        elsif user
          login_log(false, login, user['id'])
          [nil, :wrong_password]
        else
          login_log(false, login)
          [nil, :wrong_login]
        end
      end

      def current_user
        return @current_user if @current_user
        return nil unless session[:user_id]

        @current_user =
          redis.get_user_by_id(session[:user_id]) ||
          db.xquery('SELECT * FROM users WHERE id = ?', session[:user_id].to_i).first

        unless @current_user
          session[:user_id] = nil
          return nil
        end

        @current_user
      end

      def last_login
        return nil unless current_user

        @last_login ||= db.xquery('SELECT * FROM login_log WHERE succeeded = 1 AND user_id = ? ORDER BY id DESC LIMIT 2', current_user['id']).each.last
      end

      def banned_ips
        ips = []
        threshold = config[:ip_ban_threshold]

        not_succeeded = db.xquery('SELECT ip FROM (SELECT ip, MAX(succeeded) as max_succeeded, COUNT(1) as cnt FROM login_log GROUP BY ip) AS t0 WHERE t0.max_succeeded = 0 AND t0.cnt >= ?', threshold)

        ips.concat not_succeeded.each.map { |r| r['ip'] }
        succeeded = db.xquery('SELECT ip FROM
(SELECT login_log.ip, COUNT(*) AS cnt FROM
  login_log
JOIN
  (SELECT ip, MAX(id) AS last_login_id FROM login_log WHERE ip IS NOT NULL AND succeeded = 1 GROUP BY ip) as tmp
ON
  tmp.ip = login_log.ip AND
  tmp.last_login_id < login_log.id
 GROUP BY
 login_log.login) AS tmp2
 WHERE
   ?  <= cnt', threshold)
        ips.concat succeeded.each.map{ |r| r['ip'] }
        ips
      end

      def locked_users
        user_ids = []
        threshold = config[:user_lock_threshold]

        not_succeeded = db.xquery('SELECT user_id, login FROM (SELECT user_id, login, MAX(succeeded) as max_succeeded, COUNT(1) as cnt FROM login_log GROUP BY user_id) AS t0 WHERE t0.user_id IS NOT NULL AND t0.max_succeeded = 0 AND t0.cnt >= ?', threshold)

        user_ids.concat not_succeeded.each.map { |r| r['login'] }

        succeeded = db.xquery('SELECT login FROM
(SELECT login_log.login, COUNT(*) AS cnt FROM
  login_log
JOIN
  (SELECT user_id, login, MAX(id) AS last_login_id FROM login_log WHERE user_id IS NOT NULL AND succeeded = 1 GROUP BY user_id) as tmp
ON
  tmp.user_id = login_log.user_id AND
  tmp.last_login_id < login_log.id
 GROUP BY
 login_log.login) AS tmp2
 WHERE
   ?  <= cnt', threshold)
        user_ids.concat succeeded.each.map{ |r| r['login'] }
        user_ids
      end
    end

    get '/' do
      erb :index, layout: :base
    end

    post '/login' do
      user, err = attempt_login(params[:login], params[:password])
      if user
        session[:user_id] = user['id']
        redirect '/mypage'
      else
        case err
        when :locked
          flash[:notice] = "This account is locked."
        when :banned
          flash[:notice] = "You're banned."
        else
          flash[:notice] = "Wrong username or password"
        end
        redirect '/'
      end
    end

    get '/mypage' do
      unless current_user
        flash[:notice] = "You must be logged in"
        redirect '/'
      end
      erb :mypage, layout: :base
    end

    get '/report' do
      content_type :json
      {
        banned_ips: banned_ips,
        locked_users: locked_users,
      }.to_json
    end
  end
end
