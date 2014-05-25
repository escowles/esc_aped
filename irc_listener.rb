#!/usr/bin/env ruby

require 'cinch'
require 'config.rb'

ape = Cinch::Bot.new do
  configure do |cfg|
    cfg.nick = @config['irc']['nick']
    cfg.server = @config['irc']['server']
    cfg.channels = @config['irc']['channels']
    cfg.user = @config['irc']['username']
    cfg.password = @config['irc']['password']
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
  end
end

ape.start
