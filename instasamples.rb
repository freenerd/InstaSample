#!/usr/bin/env ruby

# == Synopsis
#   Instasample lets you play tracks from SoundCloud
#   It uses mplayer for playback of the streams
#   This is the customized version for Tim Exile
#
# == Examples
#     Search for ukulele tracks with max duration 12 seconds instasamples.rb -s ukulele -d 12
#
# == Usage
#   instasamples [options]
#
# == Options
#   -s, --search        String to search for on SoundCloud
#   -d, --duration      Maximum Duration of the returned tracks
#   -l, --limit         Maximum number of tracks returned (max 200)
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

require 'rubygems'
require 'soundcloud'

require File.expand_path("vendor/mplayer-ruby/lib/mplayer-ruby.rb", File.dirname(__FILE__))

#
# Defaults
#

MPLAYER_PATH = 'vendor/mplayer/mplayer'
SEARCH_TERM = 'ukulele'
DURATION = 15000
LIMIT = 6

#
# Options
#

@options = OpenStruct.new
@options.duration = DURATION
@options.search_term = SEARCH_TERM
@options.limit = LIMIT

opts = OptionParser.new do |opts|
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

def search
  p "Fetching tracks for #{@options.search_term}"
  $client.get("/tracks?q=#{URI::encode @options.search_term}&duration[to]=#{@options.duration}&limit=#{@options.number_of_samples}&filter=public,downloadable").each do |t|
    stream_url = t.stream_url.gsub(/^https:/, "http:")
    stream_url += "?consumer_key=#{CLIENT_ID}"
    stream_url += "&secret_token=#{t.secret_token}" if t.secret_token

    p "Playing #{t.title} by #{t.user.username} with stream_url #{stream_url}"
    play stream_url

    sleep t.duration / 1000 # wait for
  end

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
  p "New mplayer instance for #{location}"
  @player = MPlayer::Slave.new location, :path => MPLAYER_PATH
end

def output_help
  RDoc::usage() #exits app
end

#p ARGV
#if ARGV.length <= 1
  #output_help
#end

search
