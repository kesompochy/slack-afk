require 'active_support/time'

module App
  module Model
    class Finish < Base
      def add_list?
        true
      end

      def bot_run(uid, params)
        if params['text'].empty?
          RedisConnection.pool.set(uid, "#{params['user_name']} は退勤しました。反応が遅れるかもしれません。")
        else
          RedisConnection.pool.set(uid, "#{params['user_name']} は退勤しました。「#{params['text']}」")
        end
        tomorrow = Time.now.beginning_of_day + 3600 * 33
        RedisConnection.pool.expire(uid, (tomorrow - Time.now).to_i)

        user_presence = App::Model::Store.get(uid)
        begin_time = user_presence['today_begin']
        user_presence['today_end'] = Time.now.to_s
        App::Model::Store.set(uid, user_presence)

        bot_token_client.chat_postMessage(channel: params['channel_id'], text: "#{params['user_name']}が退勤しました。お疲れさまでした！！１", as_user: true)
        (RedisConnection.pool.get("finish_#{Date.today}") + "\n\n" || ENV['AFK_FINISH_MESSAGE'] || 'お疲れさまでした!!1') +
          (begin_time ? "始業時刻:#{Time.parse(begin_time).strftime('%H:%M')}\n" : '') +
          " 明日の#{tomorrow.strftime('%H:%M')}に自動で解除します"
      end
    end
  end
end
