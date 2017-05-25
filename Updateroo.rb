#!/usr/bin/env ruby
#
# Author: Riccardo Orizio
# Date: Wed 17 May 2017 
# Description: Finding the matches to parse
#

require 'json'
require 'net/http'
require 'uri'

require './Constants.rb'

DATABASE_COLUMN = Struct.new( :name, :type ) do
	def to_readable
		sprintf( "%s (%s)", self.name, self.type )
	end
end

def open( url )
	Net::HTTP.get( URI.parse( url ) )
end

if !File.exist?( FILE_DB_SCHEMA ) then
	data = open( "#{URL_API}schema" )
	file_write = File.open( FILE_DB_SCHEMA, "w" )
	file_write.write( data )
	file_write.close
end

# Parsing the string
schema_data = JSON.parse( File.read( FILE_DB_SCHEMA ) )

# Creating an Hash representing the DB
db_schema = Hash.new
schema_data.each do |db_attr|
	if db_schema[ db_attr["table_name"] ].nil? then
		db_schema[ db_attr["table_name"] ] = Array.new
	end
	db_schema[ db_attr["table_name"] ] << DATABASE_COLUMN.new( db_attr["column_name"], db_attr["data_type"] )
end

# Printing the DB schema
db_schema.each do |table, attrs|
	puts "#{table}"
	attrs.each do |attr|
		puts "\t#{attr.to_readable}"
	end
end

# Time from where I should start
start_time = Time.gm( 2017, 5, 15, 00, 00, 00 )
end_time = Time.gm( 2017, 5, 16, 00, 00, 00 )

[start_time, end_time].each do |i|
	puts "#{i} => #{i.to_i}"
end

# Querying the server to have a query result example
if !File.exist?( FILE_QUERY ) then
	# Ascending order so I will parse the older matches first
	query = "SELECT match_id "
	query.concat( "FROM public_matches " )
	query.concat( "WHERE start_time > " )
	query.concat( start_time.to_i.to_s )
	query.concat( " ORDER BY start_time ASC" )
	#	query.concat( "FROM match_patch " )
	#	query.concat( 'WHERE patch = "7.06" ' )
	
	puts "#{query}"
	puts "#{URI.escape( query )}"
	query_result = open( "#{URL_QUERY}#{URI.escape( query )}" )
	File.write( FILE_QUERY, query_result )
end

query_parsed = JSON.parse( File.read( FILE_QUERY ) )

puts "#{query_parsed.class}"
puts "#{query_parsed.keys}"

matches_to_parse = query_parsed["rows"].collect{ |i| i["match_id"] }
puts "First match played on #{start_time.to_s}: #{matches_to_parse[ 0 ]}"
puts "Last match played by now: #{matches_to_parse[ -1 ]}"
puts "Total matches played in this interval: #{matches_to_parse.length}"

