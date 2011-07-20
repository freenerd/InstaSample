#!/usr/bin/env ruby

# == Synopsis
#   Instasample lets you play tracks from SoundCloud
#   It uses mplayer for playback of the streams
#   This is the customized version for Tim Exile
#
# == Examples
#     Search for ukulele tracks with max duration 12 seconds instasamples.rb search -s ukulele -d 12
#
#
# == Usage
#   instasamples [mode] [options]
#
#   mode can either be "search" or "dashboard"
#
# == Options
#   -s, --search        String to search for on SoundCloud (only in search mode)
#   -d, --duration      Maximum Duration of the returned tracks
#   -l, --limit         Maximum number of tracks returned (max 200)
#   -a, --account       Account on which behalf to query (as mapped in settings) (TO BE IMPLEMENTED)
#
# == Author
#   Johan Uhle

require File.expand_path('../settings.rb', __FILE__)
# settings.rb should include:
#   CLIENT_ID
#   CLIENT_SECRET
#   ACCESS_TOKEN

require 'optparse'
require 'ostruct'
require 'rdoc/usage'
require 'uri'

require 'net/http'
require 'net/https'

require 'rubygems'
require 'soundcloud'

require File.expand_path("vendor/mplayer-ruby/lib/mplayer-ruby.rb", File.dirname(__FILE__))


#
# No more SSL Certificate warning
# http://www.5dollarwhitebox.org/drupal/node/64
#
class Net::HTTP
  alias_method :old_initialize, :initialize
  def initialize(*args)
    old_initialize(*args)
    @ssl_context = OpenSSL::SSL::SSLContext.new
    @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
end

#
# Defaults
#

MPLAYER_PATH = 'vendor/mplayer/mplayer'
SEARCH_TERM = 'tone'
DURATION = 6000
LIMIT = 6
WAITING_TIME_BETWEEN_DASHBOARD_QUERIES = 30

#
# Globals
#

# To avoid duplicate plays, we keep track of played tracks
$played_track_ids = []

#
# Options
#

@options = OpenStruct.new
@options.duration = DURATION
@options.search_term = SEARCH_TERM
@options.limit = LIMIT

opts = OptionParser.new do |opts|
  opts.on('-m', '--mode MODE')           { |mode|     @options.mode = mode                }
  opts.on('-d', '--duration DURATION')   { |duration| @options.duration = duration * 1000 }
  opts.on('-s', '--search SEARCH')       { |search|   @options.search_term = search       }
  opts.on('-l', '--limit NUMBER')        { |limit|    @options.limit = limit              }
  opts.on_tail('-h', '--help')           { output_help }
end

opts.parse!(ARGV)

$client = Soundcloud.new({
 :client_id      => CLIENT_ID,
 :client_secret  => CLIENT_SECRET,
 :access_token   => ACCESS_TOKEN
})

def dashboard
  puts "Fetching incoming tracks from dashboard for #{$client.get("/me").username}"
  $client.get("/me/activities/tracks/exclusive").collection.each do |sharing|
    t = sharing.origin.track

    unless $played_track_ids.include?(t.id)
      play_and_sleep t, t.stream_url + "?oauth_token=#{ACCESS_TOKEN}"
    end
  end

  puts "Waiting #{WAITING_TIME_BETWEEN_DASHBOARD_QUERIES} seconds until we query again"
  sleep WAITING_TIME_BETWEEN_DASHBOARD_QUERIES

  dashboard
end

def search
  puts "Fetching tracks for #{@options.search_term}"
  $client.get("/tracks?q=#{URI::encode @options.search_term}&duration[to]=#{@options.duration}&limit=#{@options.number_of_samples}&filter=public,downloadable").each do |t|
    stream_url = t.stream_url.gsub(/^https:/, "http:")
    stream_url += "?consumer_key=#{CLIENT_ID}"
    stream_url += "&secret_token=#{t.secret_token}" if t.secret_token

    play_and_sleep t, stream_url
  end
end

def play_and_sleep(t, stream_url)
  puts "Playing #{t.title} by #{t.user.username} with stream_url #{stream_url}"
  puts t.permalink_url
  puts stream_url

  # use any means necessary to somehow get this to work ...
  http = Net::HTTP.new(URI.parse(stream_url).host, 443)
  http.use_ssl = true
  final_stream = http.get(stream_url)['location']

  play final_stream

  duration =
    if t.duration.to_i < @options.duration.to_i
      t.duration.to_i / 950
    else
      @options.duration.to_i / 950
    end

  sleep duration

  begin
    # make sure player is not playing anymore
    @player.quit
  rescue
  end

  puts "Successfully played"
  $played_track_ids << t.id
end

def play(location)
  begin
    if @player
      @player.load_file location, :append
    else
      new_mplayer_instance location
    end
  rescue
    new_mplayer_instance location
  end
end

def new_mplayer_instance(location)
  puts "New mplayer instance for #{location}"
  @player = MPlayer::Slave.new location, :path => MPLAYER_PATH
end

def output_help
  RDoc::usage() #exits app
end

if ARGV[0] =~ /dash/
  dashboard
elsif ARGV[0] =~ /search/
  search
else
  output_help
end
