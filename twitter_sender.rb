#!/usr/bin/env ruby

require 'twitter'
require 'config.rb'

def send_tweet( from_nick, recipient, text )
  send_ape = Twitter::REST::Client.new do |cfg|
    cfg.consumer_key = @config['twitter']['api_key']
    cfg.consumer_secret = @config['twitter']['api_secret']
    cfg.access_token = @config['twitter']['access_token']
    cfg.access_token_secret = @config['twitter']['access_secret']
  end
  tweet = send_ape.update("@#{recipient}: #{text}")
  @tweets_sent[tweet.id] = from_nick
end

def listen_for_tweets
  receive_ape = Twitter::Streaming::Client.new do |cfg|
    cfg.consumer_key = @config['twitter']['api_key']
    cfg.consumer_secret = @config['twitter']['api_secret']
    cfg.access_token = @config['twitter']['access_token']
    cfg.access_token_secret = @config['twitter']['access_secret']
  end
  receive_ape.user do |obj|
    case obj
    when Twitter::Tweet
      puts obj.text
      from_nick = @tweets_sent[obj.in_reply_to_status_id]
    end
  end
end

# main
listen_for_tweets
