#!/usr/bin/env ruby
#
# Author: Riccardo Orizio
# Date: Mon 29 May 2017
# Description: Useful functions to access information from Dota files
#

# Functions to find details of data from files
def find_in_file_by_id( id, file )
	filecontent = JSON.parse( File.read( "#{DIR_DOTA_DATA}#{file}.json" ) )
	# New json file
	# IDs are String and not numbers, so I need to change it to a String
	if file == "heroes" then
		return filecontent[ id.to_s ][ "localized_name" ]
	else
		return filecontent[ id.to_s ][ "name" ]
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
	filecontent.keys.each do |hero_id|
		if description.include?( filecontent[ hero_id ][ "name" ] ) then
			return hero_id.to_i
		end
	end
	return ""
end

# Finding the hero id given part or the full in game name
def find_hero_id_by_localized_name( name )
	result = Array.new
	filecontent = JSON.parse( File.read( FILE_HEROES ) )
	filecontent.keys.each do |hero_id|
		if filecontent[hero_id]["localized_name"].downcase.include?( name.downcase ) then
			result.push( hero_id.to_i )
		end
	end
	return result
end

