FROM ruby:3.1
ADD Gemfile      /opt/away-from-keyboard/Gemfile
ADD Gemfile.lock /opt/away-from-keyboard/Gemfile.lock

WORKDIR /opt/away-from-keyboard
RUN gem install bundler -N
RUN bundle install --deployment --without development,test -j4

COPY socket_bot.rb presence.rb join.rb app.rb /opt/away-from-keyboard/
COPY lib/ /opt/away-from-keyboard/lib/
COPY app/ /opt/away-from-keyboard/app/
COPY config/ /opt/away-from-keyboard/config/
RUN apt-get update -qqy && apt upgrade -qqy && apt-get clean && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["bundle", "exec"]
CMD ["ruby", "socket_bot.rb"]
