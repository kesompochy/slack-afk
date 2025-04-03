module SlackApiCallable
  def bot_token_client
    App::Registry.bot_token_client
  end
end
