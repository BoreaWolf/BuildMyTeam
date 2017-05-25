#!/usr/bin/env ruby
#
# Author: Riccardo Orizio
# Date: Wed 10 May 2017 
# Description: Class to keep the stats of games
#

require 'json'

require './Constants.rb'

IterativeMean = Struct.new( :value ) do
	def set_value( new_value )
		self.value = new_value
	end

	def update_value( new_value, samples )
		self.value += ( new_value - self.value ) / samples
	end

	def to_readable
		sprintf( "%02d:%02d", self.value/60, self.value%60 )
	end

	def to_s
		self.value
	end
end

class SelfStats
	attr_accessor :picked, :time_avg

	def initialize
		@picked = 0
		@wins = 0
		@time_avg = IterativeMean.new( 0 )
	end

	def update( value, win )
		@picked += 1
		@wins += 1 if win == 1
		@time_avg.update_value( value, @picked )
	end

	def is_empty?
		return( @picked == 0 )
	end

	def to_readable
		if @picked > 0 then
			sprintf( ": %2d/%2d won matches (%6.2f%% win rate), %02d:%02d average time",
						@wins,
						@picked,
						@wins.to_f/@picked*100,
						@time_avg.value/60,
						@time_avg.value%60 )
		end
	end

	def to_s
		result = "{"
		self.instance_variables.each do |attr|
			result.concat( "\"#{attr}\":#{instance_variable_get(attr).to_s}," )
		end
		result.chomp!( "," )
		result.concat( "}" )
		return( result )
	end

	def load( loaded_data )
		#	puts "SelfStats::load Loading SelfStats data..."
		loaded_data.each do |key, value|
			if key == "@time_avg" then
				instance_variable_get( key.to_sym ).set_value( value )
			else
				instance_variable_set( key.to_sym, value )
			end
		end
	end
end

class SharedStats 
		attr_reader :picked_vs,
					:win_vs,
					:damage_done_avg,
					:damage_received_avg,
					:killed_avg,
					:died_avg

		attr_writer :damage_received_avg
	
	def initialize
		@picked_vs = 0
		@win_vs = 0
		@damage_done_avg = IterativeMean.new( 0.0 )
		@damage_received_avg = nil
		@killed_avg = IterativeMean.new( 0.0 )
		@died_avg = IterativeMean.new( 0.0 )
	end

	def update( stats, win )
		@picked_vs += 1
		@win_vs += 1 if win == 1
		stats.each do |type, value|
			case type 
			when "kills"
				update_kills( value )
			when "deaths"
				update_deaths( value )
			when "damage_done"
				update_damage_done( value )
			end
		end
	end

	def update_kills( value )
		update_avg( value, "k" )
	end

	def update_deaths( value )
		update_avg( value, "d" )
	end

	def update_damage_done( value )
		update_avg( value, "dd" )
	end

	def update_damage_received( value )
		update_avg( value, "dr" )
	end

	def is_empty?
		return( @picked_vs == 0 )
	end

	def to_s
		result = "{"
		self.instance_variables.each do |attr|
			result.concat( "\"#{attr}\":#{instance_variable_get(attr).to_s}," )
		end
		result.chomp!( "," )
		result.concat( "}" )
		return( result )
	end

	def to_readable
		if @picked_vs > 0 then
			sprintf( "\n\tPicked vs: %d\n\tWin vs: %d\n\tDamage: %.3f/%.3f\n\tKD: %.3f/%.3f\n",
						@picked_vs,
						@win_vs,
						@damage_done_avg.value,
						@damage_received_avg.value,
						@killed_avg.value,
						@died_avg.value )
		end
	end

	def load( loaded_data )
		#	puts "SharedStats::load Loading SharedStats data..."
		loaded_data.each do |key, value|
			if key == "@picked_vs" or
			   key == "@win_vs" then
				instance_variable_set( key.to_sym, value )
			else
				instance_variable_get( key.to_sym ).set_value( value )
			end
		end
	end

	private

	def update_avg( value, type )
		case type
		when "k"
			@killed_avg.update_value( value, @picked_vs )
		when "d"
			@died_avg.update_value( value, @picked_vs )
		when "dd"
			@damage_done_avg.update_value( value, @picked_vs )
		when "dr"
			@damage_received_avg.update_value( value, @picked_vs )
		end
	end
end

class Stats

	attr_reader :matches_studied

	def initialize

		# Number of matches studied
		@matches_studied = 0
		# Data matrix where all the stats are going to be stored
		@data = Hash.new

		# Get heroes id and initialize the structure
		heroes_id = Array.new
		heroes_file = JSON.parse( File.read( FILE_HEROES ) )
		heroes_id = heroes_file[ "heroes" ].collect{ |x| x["id"] }
		# SelfStats
		heroes_id.each do |hero|
			@data[ [ hero ] ] = SelfStats.new
		end
		# SharedStats
		heroes_id.each do |i|
			heroes_id.each do |j|
				@data[ [ i, j ] ] = SharedStats.new unless i == j
			end
		end

		# Pointing for damage_received_avg
		heroes_id.each do |i|
			heroes_id.each do |j|
				@data[ [ i, j ] ].damage_received_avg = @data[ [ j, i ] ].damage_done_avg unless i == j
			end
		end
	end

	def update_stats( match_data )
		# I don't want to keep a copy of the match offline, so I just process it
		# on the spot and then drop it
		#	data = JSON.parse( open( "#{URL}#{match_number}" ) )
		#	data = JSON.parse( File.read( "#{DIR_MATCHES}#{match_number}" ) )

		#	printf( "%s %s %d - %d %s %s (%d)\n",
		#				( match_data["radiant_win"] ? WIN : LOST ),
		#				TEAM_RADIANT,
		#				match_data["radiant_score"],
		#				match_data["dire_score"],
		#				( !match_data["radiant_win"] ? WIN : LOST ),
		#				TEAM_DIRE,
		#				match_data["match_id"] )

		#	match_data["players"].each do |player|
		#		print "#{find_hero_name( player["hero_id"] )}(#{player["isRadiant"]}) "
		#	end
		#	print "\n"

		# Updating the given heroes data
		match_data["players"].each do |player|
			# Updating the SelfStats
			@data[ [ player["hero_id"] ] ].update( match_data["duration"], player["win"] )

			# Updating the SharedStats
			enemies = get_team( match_data, !player["isRadiant"] )

			# Getting the data of this player
			extracted_data = extract_data( player, enemies )

			# Updating the Stats struct
			extracted_data.each do |hero_id, stats|
				@data[ [ player["hero_id"], hero_id ] ].update( stats, player["win"] )
			end
		end

		@matches_studied += 1

		#	update_damage_received( match_data )
		#	# Adding the damage received information
		#	extracted_data["damage_done"].each do |hero_id ,damage_done|
		#		if player_data["hero_id"] == hero_id
		#			result["damage_received"] << [
		#	end
	end

	def print_stats
		# Printing how many matches have been studied
		puts "Matches studied: #{@matches_studied}"

		@data.each do |key, value|
			#	puts "#{find_hero_name( key )} (#{key}):\t#{value.picked} #{value.time_avg}"
			#	printf( "%20s (%3d):\t%d %s\n",
			#				find_hero_name( key ),
			#				key,
			#				value.picked,
			#				value.time_avg )

			#	puts "#{value}"

			if !value.is_empty? then
				key.each_with_index do |k, i|
					print "#{(i > 0 ? "/" : "")}#{find_hero_name( k )}"
				end

				puts "#{value.to_readable}"
			end
		end
	end

	def print_self_stats
		puts "Matches studied: #{@matches_studied}"
		@data.each do |key, value|
			if key.length == 1 then
				if !value.is_empty? then
					printf( "%20s %s\n", find_hero_name( key[0] ), value.to_readable )
				end
			end
		end
	end

	def to_s
		#	FUCK JSON OF A BITCH
		#	JSON.generate( @data )
		#	result = "{\"@matches_studied\":#{@matches_studied},\"@data\":{"
		#	@data.each do |key, value|
		#		result.concat( "\"#{key}\":#{value}," )
		#	end
		#	result.chomp!( "," )
		#	result.concat( "}}" )
		#	return( result )

		result = "{"
		self.instance_variables.each do |attr|
			if attr.to_s == "@data" then
				result.concat( "\"#{attr}\":{" )
				@data.each do |key, value|
					result.concat( "\"#{key}\":#{value}," )
				end
				result.chomp!( "," )
				result.concat( "}," )
			else
				result.concat( "\"#{attr}\":#{instance_variable_get(attr).to_s}," )
			end
		end
		result.chomp!( "," )
		result.concat( "}" )
		return( result )
	end

	def load( loaded_data )
		#	puts "Stats::load Loading Stats data..."
		data = JSON.parse( loaded_data )

		#	data.each do |key, value|
		#		@data[ get_key_from_string( key ) ].load( value )
		#	end

		data.each do |attr, value|
			if attr == "@data" then
				value.each do |key, stat|
					@data[ get_key_from_string( key ) ].load( stat )
				end
			else
				instance_variable_set( attr.to_sym, value )
			end
		end
	end

	private

	def get_key_from_string( str )
		return( str[1..str.length-2].split( ", " ).map{ |x| x.to_i } )
	end

	# Extracting relevant data from the player given
	def extract_data( player_data, enemies )
		# Creating the results studying the data received
		result = Hash.new
		result["kills"] = extract_hero_data( player_data, "killed" )
		result["deaths"] = extract_hero_data( player_data, "killed_by" )
		result["damage_done"] = extract_hero_data( player_data, "damage" )

		# I have to remove self and teammated related damage
		# Delete elements that are not part of the enemies
		result.each do |field, values|
			values.delete_if{ |hero_id, value| !enemies.include?( hero_id ) }
		end

		# Reorganizing the structure such that it is indexed by the hero and not
		# by the type of data
		new_result = Hash.new
		result.each do |field, values|
			values.each do |hero_id, value|
				new_result[ hero_id ] = Hash.new if new_result[ hero_id ].nil?
				new_result[ hero_id ][ field ] = value
			end
		end

		#	result.each do |rk, rv|
		#		puts "#{rk}: "
		#		rv.each do |k,v|
		#			puts "\t#{k} => #{v}"
		#		end
		#	end

		#	new_result.each do |hero_id, stats|
		#		puts "#{hero_id}:"
		#		stats.each do |stat|
		#			puts "\t#{stat}"
		#		end
		#	end

		return( new_result )
	end

	# Collecting data of enemies
	def extract_hero_data( player_data, id )
		return( player_data[ id ]
					.collect{ |k,v| 
						( k.start_with?( "npc_dota_hero" ) ?
							[ k, v ] : nil ) }
					.compact
					.map{ |k,v| [ find_hero_id_by_description( k ), v ] } )
	end

	def get_team( match_data, is_radiant )
		starting = 0 + ( is_radiant ? 0 : 5 )
		return( match_data["players"].collect{ |player| player["hero_id"] }[ starting..starting + 4 ] )
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

	# In the match file they describe heroes with 'npc_dota_hero_name'
	def find_hero_id_by_description( description )
		filecontent = JSON.parse( File.read( FILE_HEROES ) )
		filecontent[ "heroes" ].each do |hero|
			if description.include?( hero[ "name" ] ) then
				return hero[ "id" ]
			end
		end
	end

end

class Statseroo

	attr_reader :last_match_studied, :last_match_time

	def initialize
		# Creating the classes of Stats that I want to study
		@data = Hash.new
		@data[ 0 ] = Stats.new
		@data[ 3000 ] = Stats.new
		@data[ 4000 ] = Stats.new
		@data[ 5000 ] = Stats.new
		@data[ 6000 ] = Stats.new
		# Keeping information of the last match studied
		@last_match_studied = 0
		@last_match_time = 0
	end

	def update_stats( match_data )
		case get_avg_mmr( match_data )
		when 0..2999
			print "Updating 0..2999"
			@data[ 0 ].update_stats( match_data )
		when 3000..3999
			print "Updating 3000..3999"
			@data[ 3000 ].update_stats( match_data )
		when 4000..4999
			print "Updating 4000..4999"
			@data[ 4000 ].update_stats( match_data )
		when 5000..5999
			print "Updating 5000..5999"
			@data[ 5000 ].update_stats( match_data )
		else
			print "Updating 6000..more"
			@data[ 6000 ].update_stats( match_data )
		end

		print " (#{get_avg_mmr( match_data )})\n"

		# Saving the ID of this match as last match studied
		@last_match_studied = match_data[ "match_id" ]
		@last_match_time = match_data[ "start_time" ]
	end

	def print_statseroo
		@data.each do |key, value|
			puts "MMR: #{key}"
			value.print_self_stats
		end

		puts "Total matches studied: #{get_total_matches_studied}"
		puts "Last match studied: #{@last_match_studied} @ #{to_human_time( @last_match_time )}"
	end

	# Saving stats on an external file
	def save
		puts "Statseroo::save Saving to file #{FILE_STATSEROO}"

		# Creating the string to save on file
		result = "{"
		self.instance_variables.each do |attr|
			if attr.to_s == "@data" then
				result.concat( "\"#{attr}\":#{JSON.generate( @data )}," )
			else
				result.concat( "\"#{attr}\":#{instance_variable_get(attr).to_s}," )
			end
		end
		result.chomp!( "," )
		result.concat( "}" )

		save_file = File.open( FILE_STATSEROO, "w" )
		save_file.write( result )
		save_file.close
	end

	def load
		puts "Statseroo::load Loading from file #{FILE_STATSEROO}"
		file_content = File.read( FILE_STATSEROO )
		file_data = JSON.parse( file_content )

		file_data.each do |key, value|
			if key == "@data" then
				value.each do |mmr, stat|
					@data[ mmr.to_i ].load( stat )
				end
			else
				instance_variable_set( key.to_sym, value )
			end
		end
	end

	private
	# Calculate the average mmr of the game
	def get_avg_mmr( data )
		players_mmr = data["players"].collect{ |player| player["solo_competitive_rank"] }.compact.map{ |mmr| mmr.to_i }

		# Checking to have at least one mmr rank of the players
		if players_mmr.empty? then
			return( 0 )
		else
			return( players_mmr.inject( 0, :+ ) / players_mmr.length )
		end
	end

	# Counting the number of matches studied through all Stats
	def get_total_matches_studied
		result = 0
		@data.each do |key, value|
			result += value.matches_studied
		end
		return result
	end

	def to_human_time( time )
		return( Time.at( time ).strftime( "%Y/%m/%d %H:%M:%S" ) )
	end

end
