#!/usr/bin/env ruby
#
# Author: Riccardo Orizio
# Date: Wed 10 May 2017 
# Description: Class to keep the stats of games
#

require "json"

require "./Constants.rb"
require "./FindingFunctions.rb"

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

	def win_rate
		if @picked == 0 then
			-1
		else
			@wins.to_f / @picked * 100
		end
	end

	def to_readable
		if @picked > 0 then
			sprintf( ": %3d/%3d won matches (%6.2f%% win rate), %02d:%02d average time",
						@wins,
						@picked,
						win_rate,
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

	# Parameters used in the rate computation
	# Damage
	@@alpha = 0.9
	# KDA
	@@beta = 0.5
	# Win rate
	@@gamma = 0.7
	
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

	# Rating how good a certain matchup could be based on the stats collected
	#
	def rate
		rating = 0
		rating += @@alpha * ( @damage_received_avg.value == 0 ? 
							  @damage_done_avg.value.to_f : 
							  @damage_done_avg.value.to_f / @damage_received_avg.value )
		rating += @@beta * ( @died_avg.value == 0 ?
							 @killed_avg.value.to_f :
							 @killed_avg.value.to_f / @died_avg.value )

		rating += @@gamma * ( @picked_vs == 0 ? 
							  @wins_vs.to_f :
							  @win_vs.to_f / @picked_vs )

		return( is_empty? ? MATCHUPS_PENALTY : rating )
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

	# Checking if all attributes are equal to 0
	def is_empty?
		return(
				self.instance_variables
					.map{ |attr| instance_variable_get( attr ) }
					.map{ |v| ( v.is_a?( Struct ) ? v.value : v ) }
					.all?{ |v| v == 0 }
			  )
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
		#	Old json file
		#	heroes_id = heroes_file[ "heroes" ].collect{ |x| x["id"] }
		# New json file is structured as a Hash, so the ids are the keys of it
		# Transforming the ids from string to integers 
		heroes_id = heroes_file.keys.map!{ |x| x.to_i }
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
		
		# Updating the given heroes data
		match_data["players"].each do |player|
			# Updating the SharedStats
			enemies = get_team( match_data, !player["isRadiant"] )

			# Getting the data of this player
			extracted_data = extract_data( player, enemies )

			# Problems with the match, no data could have been extracted due to
			# some problems on their side 3233340300
			if extracted_data.nil? then
				return false
			end
			

			# Updating the Stats struct
			extracted_data.each do |hero_id, stats|
				@data[ [ player["hero_id"], hero_id ] ].update( stats, player["win"] )
			end

			# Shifted the SelfStats update part after dued to problems with the
			# parser. In this way I will update my stats only if I can get all
			# the information I want

			# Updating the SelfStats
			@data[ [ player["hero_id"] ] ].update( match_data["duration"], player["win"] )
		end

		@matches_studied += 1

		return( true )
	end

	def best_against( hero_ids )
		# Taking data related only the hero requested, calculating the rate and
		# sorting by it
		# Collect: taking the info about the hero requested
		# Compact: removing non hero data, saved as nil
		# Map: Creating the data needed. Picked_vs is set to a minimum of 1 in
		#	order to penalize unknown matchups
		result = Array.new
		hero_ids.each do |hero|
			result.push(
				@data.collect{ |k, v| ( k[ 1 ] == hero ? [ k, v ] : nil ) }
					 .compact
				 	 .map{ |k, v| 
						 [ 
							 find_hero_name( k[ 0 ] ),
							 v.rate,
							 ( v.picked_vs == 0 ? 1 : v.picked_vs ),
							 hero 
						 ] }
			)
		end

		# I have to combine the results to a single list of best picks
		# Some parameters might be needed, something to consider
		result = result.flatten( 1 )
					   .group_by{ |hero, rate, picks, initial| hero }
					   .map{ |hero, info| 
							[ 
								hero,
								(
									info.inject( 0 ){ |res, i| res + i[ 2 ] } == 0 ?
									MATCHUPS_PENALTY :
									info.inject(0){ |res, i| res + i[ 1 ] * i[ 2 ] } / info.inject( 0 ){ |res, i| res + i[ 2 ] }
								),
								info.collect{ |h, r, p, i| 
									[ find_hero_name( i ), r, p ] }
							]
					   }
					   .sort_by{ |h, r, p| r }
					   .reverse

		return( result )
	end

	def win_rate
		# Looking only to the SelfStats
		@data.select{ |k, v| k.length == 1 }
			 .map{ |k, v| [ find_hero_name( k.first ), v.win_rate, v.picked ] }
			 .sort_by{ |name, wr, p| wr }
			 .reverse
	end

	def pick_rate
		# Checking to have at least one match in this bracket
		return nil if @matches_studied == 0

		@data.select{ |k, v| k.length == 1 }
			 .map{ |k, v| [ find_hero_name( k.first ), v.picked.to_f / @matches_studied * 100 ] }
			 .sort_by{ |name, pr| pr }
			 .reverse
	end

	def print_stats
		# Printing how many matches have been studied
		puts "Matches studied: #{@matches_studied}"

		@data.each do |key, value|
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
		#	I'll do it myself

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
		# Checking for any problems related with the parser
		# As happened in match 3233340300
		if !player_data["killed"].nil? then
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

			return( new_result )
		else
			return( nil )
		end
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

end

class Statseroo

	attr_reader :last_match_studied, :last_match_time

	def initialize
		# Creating the classes of Stats that I want to study
		@data = Hash.new
		MEDALS.each do |medal|
			@data[ medal ] = Stats.new
		end
		# Keeping information of the last match studied
		@last_match_studied = 0
		@last_match_time = 0
	end

	def update_stats( match_data )
		avg_rank = 5 * ( get_avg_mmr( match_data ) / 5.0 ).round( 0 )
		# The index of the model is given by the second digit of the medal
		# average
		medal_index = ( avg_rank / 10 ).round( 0 )
		# Other way to obtain the medal index
		#	MEDALS_RANGES.each.with_index do |range, i|
		#		if range.cover?( avg_rank ) then
		#			medal_index = i
		#		end
		#	end
		
		print "Updating #{MEDALS[ medal_index ]} #{avg_rank%10} "
		result = @data[ MEDALS[ medal_index ] ].update_stats( match_data )

		print "(#{get_avg_mmr( match_data )})"

		# Checking if any errors occured during the stats update
		# Errors related to the parser itself
		if result then
			# Saving the ID of this match as last match studied
			@last_match_studied = match_data[ "match_id" ]
			@last_match_time = match_data[ "start_time" ]
		else
			print " <== Problem with parsed match #{match_data["match_id"]}"
		end
		puts "\n"
	end

	# Receiving an array of hero id I will try to find which hero is more
	# suitable against them for each mmr skill level
	def best_against( hero_ids )
		result = Hash.new
		@data.each do |k, v|
			result[ k ] = v.best_against( hero_ids )
		end
		return result
	end

	def win_rate
		result = Hash.new
		@data.each do |k, v|
			result[ k ] = v.win_rate
		end
		return result
	end

	def pick_rate
		result = Hash.new
		@data.each do |k, v|
			result[ k ] = [ v.matches_studied, v.pick_rate ]
		end
		return result
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
					@data[ mmr ].load( stat )
				end
			else
				instance_variable_set( key.to_sym, value )
			end
		end
	end

	private
	# Calculate the average mmr of the game
	def get_avg_mmr( data )
		# Getting the rank of each player
		players_rank = data["players"].collect{ |player| player["rank_tier"] }.compact

		# Returning the average or 0 if none of the players have one
		if players_rank.empty? then
			return( 0 )
		else
			return( players_rank.compact.inject( 0.0, :+ ) / players_rank.compact.length ).round( 0 )
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
