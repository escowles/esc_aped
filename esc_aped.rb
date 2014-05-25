#!/usr/bin/env ruby

require 'config.rb'
require 'cinch'
require 'thread'
require 'twitter'

# sent a tweet
# from_nick: irc nick who initiated the message
# recipient: twitter nick of the user to tweet at
# text: tweet text
def twitter_send( from_nick, recipient, text )
  unless @twitter_send do
    @twitter_send = Twitter::REST::Client.new do |cfg|
      cfg.consumer_key = @config['twitter']['api_key']
      cfg.consumer_secret = @config['twitter']['api_secret']
      cfg.access_token = @config['twitter']['access_token']
      cfg.access_token_secret = @config['twitter']['access_secret']
    end
  end
  tweet = @twitter_send.update("@#{recipient}: #{text}")
  @tweets_sent[tweet.id] = from_nick
end

# listen to tweets and forward replies to irc
def twitter_listen
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
      from_nick = @tweets_sent[obj.in_reply_to_status_id]
      irc_send( from_nick, obj.text )
    end
  end
end

# send an irc message
# recipient: irc nick of the user to mention
# text: message text
def irc_send( recipient, text )
  irc_listen # setup @irc connection
  @irc.send( "#{recipient}: #{text}" )
end

# listen to irc messages and forward mentions to twitter
def irc_listen
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

    on :message, /esc_aped/ do |msg|
      text = "*#{msg.action_message}" if msg.action_message
      text ||= msg.message
      venue = msg.channel || "@#{msg.target}"
      if msg.message =~ /^esc_aped/
        msg.reply "you rang?"
      else
        msg.reply "yes?"
      end

      puts "\n#{msg.time} #{venue} #{msg.user} #{text}\n\n"
      recipient = "escowles" # XXX
      twitter_send( msg.user, recipient, text )
    end
  end
end

threads = []
threads[0] = Thread.new { irc_listen }
threads[1] = Thread.new { twitter_listen }
threads.each { |t| t.join } # wait for all threads to finish
