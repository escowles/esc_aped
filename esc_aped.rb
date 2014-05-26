#!/usr/bin/env ruby

# esc_aped - an irc/twitter bridge
# 
# listens to irc channel(s) and forwards messages to twitter, keeps track of
# messages so twitter replies are turned into irc replies

require 'yaml'
require 'cinch'
require 'thread'
require 'twitter'

# listen to irc messages and forward mentions to twitter
def irc_to_twitter
  unless @irc
    @irc = Cinch::Bot.new do
      configure do |cfg|
        cfg.nick = @config['irc']['nick']
        cfg.server = @config['irc']['server']
        cfg.channels = @config['irc']['channels']
        cfg.user = @config['irc']['username']
        cfg.password = @config['irc']['password']
      end
    end

    on :message, /"#{nick}"/ do |msg|
      unless @twitter_send do
        @twitter_send = Twitter::REST::Client.new do |cfg|
          cfg.consumer_key = @config['twitter']['api_key']
          cfg.consumer_secret = @config['twitter']['api_secret']
          cfg.access_token = @config['twitter']['access_token']
          cfg.access_token_secret = @config['twitter']['access_secret']
        end
      end

      mention = @config['twitter']['mention']
      text = "@#{mention}: " if mention
      if msg.action_message 
        text += "*#{msg.action_message}"
      else
        text += msg.message
      end
      # XXX: strip nick: prefix...

      tweet = @twitter_send.update(text)
      @tweets_sent[tweet.id] = msg
    end
  end
end

# listen to tweets and forward replies to irc
def twitter_to_irc
  unless @twitter_receive do
    @twitter_receive = Twitter::Streaming::Client.new do |cfg|
      cfg.consumer_key = @config['twitter']['api_key']
      cfg.consumer_secret = @config['twitter']['api_secret']
      cfg.access_token = @config['twitter']['access_token']
      cfg.access_token_secret = @config['twitter']['access_secret']
    end
  end
  @twitter_receive.user do |obj|
    case obj
    when Twitter::Tweet
      msg = @tweets_sent[obj.in_reply_to_status_id]
      msg.reply( obj.text )
    end
  end
end


# load config
@config = YAML.load_file('config.yml')

# start irc_to_twitter and twitter_to_irc
threads = []
threads[0] = Thread.new { irc_to_twitter }
threads[1] = Thread.new { twitter_to_irc }
threads.each { |t| t.join } # wait for all threads to finish
