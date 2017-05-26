#!/usr/bin/env ruby
#
# Author: Riccardo Orizio
# Date: Wed 10 May 2017 
# Description: Constants
#

# Directories
DIR_DOTA_DATA = "./DotaData/"
DIR_MATCHES = "./Matches/"

# Files
FILE_HEROES = "#{DIR_DOTA_DATA}heroes.json"
FILE_LOBBIES = "#{DIR_DOTA_DATA}lobbies.json"

FILE_STATSEROO = "./AllStats.Dota"

FILE_DB_SCHEMA = "./DB.Schema"
FILE_QUERY = "./Query.try"

# URL for retrieving data
URL_SITE = "https://www.opendota.com/matches/"
URL_API = "https://api.opendota.com/api/"
URL_MATCHES = "#{URL_API}matches/"
URL_EXPLORER = "explorer?sql="
URL_QUERY = "#{URL_API}#{URL_EXPLORER}"
SCRIPT_BUILD = "/build/641f6f1bb5fb15bb60f5.bundle.js"

# Constants used for cute printing
UNKNOWN_NAME_PLAYER = "Unknown player"
UNKNOWN_DATA = "No data"
TEAM_RADIANT = "Radiant"
TEAM_DIRE = "Dire"
WIN = "Victorious"
LOST = "Defeated"

# Time where I should stop controlling new matches
DELTA_TIME = 10 * 60
# Every X matches parsed I will save the stats
SAVING_INTERVAL = 50

