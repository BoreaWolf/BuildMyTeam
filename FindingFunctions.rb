#!/usr/bin/env ruby
#
# Author: Riccardo Orizio
# Date: Mon 29 May 2017
# Description: Useful functions to access information from Dota files
#

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
	return ""
end

def find_hero_id_by_localized_name( name )
	result = Array.new
	filecontent = JSON.parse( File.read( FILE_HEROES ) )
	filecontent[ "heroes" ].each do |hero|
		if hero["localized_name"].downcase.include?( name.downcase ) then
			result.push( hero[ "id" ] )
		end
	end
	return result
end

