#!/usr/bin/env ruby
#
# Author: Riccardo Orizio
# Date: Fri 05 May 2017
# Description: Build a Dota 2 team real time
#

require 'json'
require 'net/http'
require 'nokogiri'
require 'time'
require 'uri'

require './Statseroo.rb'

#	IterativeMean = Struct.new( :value, :samples )

# Open a url stream
def open( url )
	Net::HTTP.get( URI.parse( url ) )
end

def is_useful?( match_data )
	return( is_parsed?( match_data ) and is_ranked?( match_data ) )
end

def is_parsed?( match_data )
	return( !match_data["cosmetics"].nil? )
end

# Looking in 'lobbies.json', type 7 is a ranked match
def is_ranked?( match_data )
	return( match_data["lobby_type"] == 7 )
end

def is_match?( match_data )
	return( !( match_data.keys.include?( "error" ) or 
			   match_data["start_time"].nil? ) )
end

def match_status( match_data )
	return( "Not a match\n" ) if !is_match?( match_data )
	return( "Not ranked\n" ) if !is_ranked?( match_data )
	return( "Not parsed\n" ) if !is_parsed?( match_data )
end

def get_matches_to_parse( last_match_time )
	# Creating the query to have the list of matches to parse
	# Ascending order so I will parse the older matches first
	query = "SELECT match_id "
	query.concat( "FROM public_matches " )
	query.concat( "WHERE start_time > " )
	query.concat( last_match_time.to_s )
	query.concat( " ORDER BY start_time ASC" )
	
	query_result = JSON.parse( open( "#{URL_QUERY}#{URI.escape( query )}" ) )

	return( query_result["rows"].collect{ |i| i["match_id"] } )
end

def to_human_time( time )
	return( Time.at( time ).strftime( "%Y/%m/%d %H:%M:%S" ) )
end

def num_digits( number )
	return( Math.log10( number ).to_i + 1 )
end

def update_from( date_time, stats )
	# Printing some info to the user
	puts "Updating Stats starting from #{to_human_time( date_time )}"

	# Starting from the last match studied, I will update my stats until the
	# most recent game, going forward through time
	matches_to_parse = get_matches_to_parse( date_time )

	matches_controlled = 0
	matches_parsed = 0
	#	last_delta_time = DELTA_TIME + 1
	matches_to_parse.each.with_index do |match, i|
		# Reading data from the website
		data = JSON.parse( open( "#{URL_MATCHES}#{match}" ) )

		# Nice printing
		printf( "%#{num_digits(matches_to_parse.length)}d/%d) ",
						i + 1,
						matches_to_parse.length )
		print "#{match}: #{match_status( data )}"
		matches_controlled += 1

		if is_useful?( data ) then
			stats.update_stats( data )
			matches_parsed += 1
		end

		# Saving every X matches parsed
		stats.save if matches_controlled % SAVING_INTERVAL == 0

		# Waiting 1 second, as required by the website
		sleep( 1 )
	end

	#	begin
	#		# Going through the matches increasing the ID by one on each step
	#		match_id += 1
	#		# Reading data from the website
	#		data = JSON.parse( open( "#{URL_MATCHES}#{match_id}" ) )

	#		# Nice printing
	#		print "#{match_id}: #{match_status( data )}"
	#		matches_controlled += 1

	#		#	# Saving the statseroo every X games controlled
	#		#	if matches_controlled % SAVING_INTERVAL == 0 then
	#		#		statseroo.save
	#		#	end

	#		# Waiting 1 second, as required by the website
	#		sleep( 1 )

	#		# To avoid nil data (not existing match), I will keep track of the time
	#		# of the last correct match parsed and if it is too close to the current
	#		# time then I will stop the updating procedure
	#		next if !is_match?( data ) and last_delta_time > DELTA_TIME
	#		break if !is_match?( data )

	#		# Parsing it if it is useful
	#		statseroo.update_stats( data ) unless !is_useful?( data )
	#		# Updating matches parsed counter and saving to file
	#		if is_useful?( data ) then
	#			matches_parsed += 1
	#			statseroo.save
	#		end

	#		# Updating the delta time
	#		last_delta_time = ( Time.now - Time.at( data[ "start_time" ] ) )

	#	end while( last_delta_time > DELTA_TIME )

	# Saving the updates done
	puts "Updated stats with #{matches_parsed} matches over #{matches_controlled} controlled"
end

# Functions to find details of data from files
def find_in_file_by_id( id, file )
	filecontent = JSON.parse( File.read( "#{DIR_DOTA_DATA}#{file}.json" ) )
	filecontent[ file ].each do |item|
		if item[ "id" ] == id then
			if file == "heroes" then
				return item[ "localized_name" ]
			else
				return item[ "name" ]
			end
		end
	end
end

def find_hero_name( id )
	find_in_file_by_id( id, "heroes" )
end

def find_lobby( id )
	find_in_file_by_id( id, "lobbies" )
end

def find_mode( id )
	find_in_file_by_id( id, "mods" )
end

def find_region( id )
	find_in_file_by_id( id, "regions" )
end

def find_item( id )
	find_in_file_by_id( id, "items" )
end

def print_key_value_array( data )
	if data.class != NilClass then
		data.sort.each do |key, value|
			puts "\t#{key}: #{value}"
		end
	else
		puts "\t#{UNKNOWN_DATA}"
	end
end

def print_player_info( player_data )
	puts "***********************************************************"
	# Players/Personaname-Name-PersonName
	puts "Person Name: #{( player_data["personaname"].class == NilClass ? UNKNOWN_NAME_PLAYER : player_data["personaname"] )}"
	# #{player_data["name"]}/#{player_data["person_name"]}"
	# Players/HeroId
	puts "Hero: #{find_hero_name( player_data["hero_id"])} (#{player_data["hero_id"]})"
	# Players/Solo_competitive_rank
	puts "MMR: '#{( p["solo_competitive_rank"].nil? ? UNKNOWN_DATA : p["solo_competitive_rank"] )}'"
	# Players/isRadiant
	puts "Team: #{( player_data["isRadiant"] ? TEAM_RADIANT : TEAM_DIRE )}"
	# Players/Win Lose  #{player_data["win"]}/#{player_data["lose"]}"
	puts "Win/Lose: #{( player_data["win"] ? WIN : LOST )}"
	# Players/Kills
	puts "Kills: #{player_data["kills"]}"
	# Players/HeroKills
	puts "Hero Kills: #{player_data["hero_kills"]}"
	# Players/TowerKills
	puts "Tower Kills: #{player_data["tower_kills"]}"
	# Players/LaneKills
	puts "Lane Kills: #{player_data["lane_kills"]}"
	# Players/Denies
	puts "Denies: #{player_data["denies"]}"
	# Players/HeroDamage
	puts "Hero Damage: #{player_data["hero_damage"]}"
	# Players/Ability_uses
	puts "Abilities:"
	print_key_value_array( player_data["ability_uses"] )
	# Players/Ability_upgrades_arr: skill tree evolution
	# Players/Killed
	puts "Killed:"
	print_key_value_array( player_data["killed"] )
	# Players/KilledBy
	puts "Killed By:"
	print_key_value_array( player_data["killed_by"] )
	# Players/Damage
	puts "Damage:"
	print_key_value_array( player_data["damage"] )
	# Players/DamageInflictor
	puts "Damage Inflictor:"
	print_key_value_array( player_data["damage_inflictor"] )
	puts "***********************************************************"
end

def print_full_player( player_data )
	player_data.each do |key, value|
		puts "#{key} (#{key.class}/#{value.class})"
		if value.class == Array or value.class == Hash then
			if key.include? "log" or
			   key == "cosmetics" or
			   key == "times" or
			   key.end_with? "_t" or
			   key.end_with? "arr" then
				puts "#{key}: #{value}"
			else
				print_key_value_array( value )
			end
		else
			puts "#{value}"
		end
		#	puts "#{value}"
		#	if( value.class == Array ) then
		#		print_key_value_array( value )
		#	end
	end
end

# Detailed list of what a file contains
def print_full_file()
	#	List of all information in a file
	#	puts "#{data["match_id"]}"					# Match ID
	#	puts "#{data["barracks_status_dire"]}"		#
	#	puts "#{data["barracks_status_radiant"]}"	#
	#	puts "#{data["chat"]}"						# Chat list
	#	puts "#{data["cluster"]}"					# Region where the game has been played
	#	puts "#{data["cosmetics"]}"					# Cosmetics list
	#	puts "#{data["dire_score"]}"				# Dire kills
	#	puts "#{data["duration"]}"					# Duration in seconds
	#	puts "#{data["engine"]}"					# 
	#	puts "#{data["first_blood_time"]}"			# First blood in seconds
	#	puts "#{data["game_mode"]}"					# Game mode
	#	puts "#{data["human_players"]}"				# Number of players
	#	puts "#{data["leagueid"]}"					# 
	#	puts "#{data["lobby_type"]}"				# Public/Ranked/...
	#	puts "#{data["match_seq_num"]}"				# Sequential match ID, I think
	#	puts "#{data["negative_votes"]}"			# Negative votes
	#	puts "#{data["objectives"]}"				# Objectives with times
	#	puts "#{data["picks_bans"]}"				# Pick/ban
	#	puts "#{data["positive_votes"]}"			# Positive votes
	#	puts "#{data["radiant_gold_adv"]}"			# Radiant gold advantage
	#	puts "#{data["radiant_score"]}"				# Radiant kills
	#	puts "#{data["radiant_win"]}"				# Result of the match, Radiant side
	#	puts "#{data["radiant_xp_adv"]}"			# Radiant xp advantage
	#	puts "#{data["skill"]}"						# 
	#	puts "#{data["start_time"]} #{Time.at( data["start_time"] ).strftime( "%Y/%m/%d %H:%M:%S" )}"					# Start time in seconds
	#	puts "#{data["teamfights"]}"				# List of death with details of abilities and items used
	#	puts "#{data["tower_status_dire"]}"			#
	#	puts "#{data["tower_status_radiant"]}"		#
	#	puts "#{data["version"]}"					#
	#	puts "#{data["replay_salt"]}"				#
	#	puts "#{data["series_id"]}"					#
	#	puts "#{data["series_type"]}"				#
	#	puts "#{data["players"]}"					# Players and respective heroes data
	#	puts "#{data["patch"]}"						# Patch
	#	puts "#{data["region"]}"					# 
	#	puts "#{data["all_word_counts"]}"			# List of words used in	global chat
	#	puts "#{data["my_word_counts"]}"			#
	#	puts "#{data["throw"]}"						# Max Gold throw by losing team
	#	puts "#{data["loss"]}"						# Max Gold difference by winning team
	#	puts "#{data["replay_url"]}"				# URL of match replay
end


# Creating the Statseroo object
statseroo = Statseroo.new

case ARGV[ 0 ]
# Creating a new empty Statseroo file
when "new"
	#	Dir[ "#{DIR_MATCHES}*" ].each do |match|
	#		#	match = "./Matches/3159661273"
	#		puts "#{match}"
	#		data = JSON.parse( File.read( match ) )

	#		start_time = Time.now
	#		# Check if the match is parsed, otherwise I will not process it
	#		statseroo.update_stats( data ) unless !is_useful?( data )# !is_useful?( data )
	#		end_time = Time.now
	#		puts "Match #{match} studied in #{end_time-start_time}"
	#	end
	
# Updating the current Statseroo file via the website
when "update"
	# Loading the stats from a file
	statseroo.load

	# Updating starting from the last match studied
	update_from( statseroo.last_match_time, statseroo )
	
# Loading local matches file
when "local"
	# Loading the stats from a file
	statseroo.load

	# Reading local data
	Dir[ "#{DIR_MATCHES}*" ].each do |match|
		# Loading data
		data = JSON.parse( File.read( match ) )

		# Check if the match is parsed, otherwise I will not study it
		statseroo.update_stats( data ) unless !is_useful?( data )
	end

when "show"
	# Loading the stats from the file
	statseroo.load

	# Showing the stats collected
	statseroo.print_statseroo

# Parsing a single match
when "match"
	# Reading the match number to parse
	match_number = ARGV[ 1 ].to_i
	match_file = "#{DIR_MATCHES}#{( match_number.nil? ? 3157319702 : match_number )}"
	
	if !File.exist?( match_file ) then
		puts "Downloading data for #{match_file}..."
		# Reading data from The Internet
		data = open( "#{URL_MATCHES}#{match_number}" )
		# Saving data locally
		file_write = File.open( "#{DIR_MATCHES}#{match_number}", "w" )
		file_write.write( data )
		file_write.close
	else
		data = File.read( match_file )
	end
	
	data = JSON.parse( data )
	#	data = JSON.parse( open( "#{URL}#{match_number}" ) )

	# Updating data with the match provided
	statseroo.update_stats( data ) unless !is_useful?( data )

when "site"

	#
	#	Can't parse the web page because they still go through the api to get
	#	the match information
	#
	#	match_number = ( ARGV[ 1 ].nil? ? 3198083879 : ARGV[ 1 ].to_i )
	#	site = "#{URL_SITE}#{match_number}#{SCRIPT_BUILD}"
	#	puts "#{site}"
	#	content = Nokogiri::HTML( open( site ) )
	#	puts "#{content}"
	#	puts "#{content.css( "script" )[-1]}"
	#	script = content.css( "script" )[-1][ "src" ]
	#	puts "#{script}"

# Starting from a specific date
else
	begin
		# Parsing the date given as input
		start_time = Time.parse( ARGV[ 0 ] )
		# Updating from the date parsed from the input
		update_from( start_time.to_i, statseroo )
	rescue ArgumentError
		puts "Not a date dude."
	end
end

# Saving the new stats
#	statseroo.save

#	# Printing all the stats
#	statseroo.print_statseroo
	