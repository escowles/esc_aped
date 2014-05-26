#!/usr/bin/env ruby

# esc_aped - an irc/twitter bridge
# 
# listens to irc channel(s) and forwards messages to twitter, keeps track of
# messages so twitter replies are turned into irc replies

require 'yaml'
require 'cinch'
require 'thread'
require 'twitter'

class EscApe

  # listen to irc messages and forward mentions to twitter
  def irc_to_twitter
    irc_client = Cinch::Bot.new do
      configure do |cfg|
        cfg.nick = $config['irc']['nick']
        cfg.server = $config['irc']['server']
        cfg.channels = $config['irc']['channels']
        cfg.user = $config['irc']['username']
        cfg.password = $config['irc']['password']
      end
  
      nick = $config['irc']['nick']
      on :message, /#{nick}/ do |msg|
  
        mention = $config['twitter']['mention']
        text = "@#{mention}: " if mention
        if msg.action_message 
          text += "*#{msg.action_message}"
        else
          text += msg.message.gsub(/^#{nick}[:]? /,'')
        end
  
        tweet = $twitter_client.update(text)
        $tweets_sent = {} unless $tweets_sent
        $tweets_sent[tweet.id] = msg
      end
    end
  
    irc_client.start
  end

  # listen to tweets and forward replies to irc
  def twitter_to_irc
  
    # get last mention
    mentions = $twitter_client.mentions_timeline( :count => 1 )
    last = mentions.last.id if mentions.last
    puts "last mention: #{last}"
  
    # loop and get new mentions
    while true do
      mentions = $twitter_client.mentions_timeline( :since_id => last )
      mentions.each do |mention|
        last = mention.id
        puts "mention: #{mention.id}: #{mention.text}"
        msg = $tweets_sent[mention.in_reply_to_status_id]
        msg.reply( mention.text )
      end
      sleep 60
    end
  
  end

  # load config and start listeners
  def start
    # load config
    $config = YAML.load_file('config.yml')
    $twitter_client = Twitter::REST::Client.new do |cfg|
      cfg.consumer_key = $config['twitter']['api_key']
      cfg.consumer_secret = $config['twitter']['api_secret']
      cfg.access_token = $config['twitter']['access_token']
      cfg.access_token_secret = $config['twitter']['access_secret']
    end
  
    # start irc_to_twitter and twitter_to_irc
    threads = []
    threads[0] = Thread.new { irc_to_twitter }
    threads[1] = Thread.new { twitter_to_irc }
    threads.each { |t| t.join } # wait for all threads to finish
  end

end

EscApe.new.start
