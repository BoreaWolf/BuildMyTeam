#!/usr/bin/env ruby
#
# Author: Riccardo Orizio
# Date: Mon 29 May 2017
# Description: Giving some names, I will try to answer with the best pick
#	against them.
#

require "./FindingFunctions.rb"
require "./Statseroo.rb"

# Finding the hero ids of the given input arguments
input_heroes = ARGV.map{ |x| find_hero_id_by_localized_name( x ) }

# Checking for inconsistencies in the names given via console
status = String.new
input_heroes.each.with_index do |hero_id, i|
	# Found many heroes given the input argument
	if hero_id.length > 1 then
		status.concat( "I can't uniquely identify '#{ARGV[ i ]}': #{hero_id.length} matches found (" )
		status.concat( hero_id.map{ |x| find_hero_name( x ) }.join( "/" ) )
		status.concat( ")\n" )

	# No heroes found
	elsif hero_id.length == 0 then
		status.concat( "Can't find heroes names '#{ARGV[ i ]}'" )
	end
end

# Updating the user about his inputs
if status.empty? then
	puts "Who is the best against"
	puts input_heroes.map.with_index{ |id,i| "\t#{ARGV[ i ]} => #{find_hero_name( id.first )} [#{id.first}]" }.join( "\n" )
else
	puts "Error: #{status}"
	exit
end

# Flattening the array, knowing that they are unique
input_heroes.flatten!

# The inputs are correct, I can try to look up in the stats file to who is more
# suitable to deal with those picks
statseroo = Statseroo.new
statseroo.load

ans = statseroo.best_against( input_heroes )
ans.each do |k, v|
	puts "MMR: #{k}"
	v[0..9].each do |name, rate, matchups|
		puts "\t#{name} @ #{rate} on #{matchups} matchups"
	end
end
