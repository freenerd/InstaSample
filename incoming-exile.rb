#!/usr/bin/env ruby

require File.expand_path('../settings.rb', __FILE__)
# settings.rb should include:
#   CLIENT_ID
#   CLIENT_SECRET
#   ACCESS_TOKEN

require 'soundcloud'
require 'osc-ruby'

FILE_DIRECTORY = 'temp'
WAIT_BETWEEN_PLAYBACK = 1

SEARCH_TERM = 'cat'
DURATION = 5000

$client = Soundcloud.new({
 :client_id      => CLIENT_ID,
 :client_secret  => CLIENT_SECRET,
 :access_token   => ACCESS_TOKEN
})

$osc = OSC::Client.new('localhost', 8000)

class Track
  attr_accessor :duration, :file_name

  def initialize(file_name, duration)
    @file_name = file_name
    @duration = duration
    p "new track saved at #{@file_name}"
  end

  def play
    p "Playing track #{@file_name} with duration #{@duration}"
    Kernel.fork { `afplay #{self.full_file_name}` }
    sleep 0.22
    $osc.send( OSC::Message.new("/abletonlive/record"))
  end

  def full_file_name
    "#{FILE_DIRECTORY}/#{@file_name}"
  end
end

class TrackQueue
  attr_accessor :processed_track_ids

  def initialize
    @unplayed_tracks = []
    @played_tracks = []
    @processed_track_ids = []
  end

  def has_unplayed_tracks?
    @unplayed_tracks.size != 0
  end

  def play_next_track
    # find the next finished unplayed track
    next_track = nil
    @unplayed_tracks.each do |track|
      if FileTest.exists?(track.full_file_name)
        track.play
        next_track = track.dup
        @unplayed_tracks = @unplayed_tracks - [track]
        break
      else
        p "track #{track.file_name} does not exist yet"
      end
    end
    next_track
  end

  def get_new_tracks
    $client.get("/tracks?q=#{SEARCH_TERM}&duration[to]=#{DURATION}&limit=8&filter=public,streamable").each do |t|
      next if @processed_track_ids.include? t.id

      p t.title

      stream_url = t.stream_url.gsub(/^https:/, "http:") +
        "?consumer_key=#{CLIENT_ID}&secret_token=#{t.secret_token}"

      file_name = "#{t.id}-#{t.permalink}.mp3"
      Kernel.fork do
        wget_call = "wget -O '#{FILE_DIRECTORY}/#{file_name}' '#{stream_url}'"
        wget = IO.popen(wget_call)
        wget_output = wget.readlines
      end

      @unplayed_tracks << Track.new(file_name, t.duration)
      @processed_track_ids << t.id
    end
  end
end


# setup
track_queue = TrackQueue.new

# play new tracks time
play_next_track = Time.now.to_i

# get tracks
track_queue.get_new_tracks

while true
  p "playing next track at #{play_next_track} (now == #{Time.now.to_i}"

  if play_next_track <= Time.now.to_i
    p "stop playback"
    $osc.send( OSC::Message.new("/abletonlive/stop"))

    if track_queue.has_unplayed_tracks?
      track = track_queue.play_next_track
      p "New track #{track}"
      if track
        play_next_track = Time.now.to_i + (track.duration / 1000) + WAIT_BETWEEN_PLAYBACK
        p "playing a new track until #{play_next_track}"
      else
        play_next_track = Time.now.to_i + 5 + WAIT_BETWEEN_PLAYBACK
      end
    else
      play_next_track = Time.now.to_i + 5 + WAIT_BETWEEN_PLAYBACK
    end
  end

  # check for more tracks?
  #track_queue.get_new_tracks

  sleep 2
end
