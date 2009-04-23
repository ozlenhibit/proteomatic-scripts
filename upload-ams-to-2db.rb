# Copyright (c) 2007-2008 Michael Specht
# 
# This file is part of Proteomatic.
# 
# Proteomatic is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# Proteomatic is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with Proteomatic.  If not, see <http://www.gnu.org/licenses/>.

require 'include/proteomatic'


class UploadAMSto2DB < ProteomaticScript
	def run()
	  File.open('c:\dev\proteomatic\test_neu.txt', 'w+') do |file|
      file.puts 'Hall�chen'
	  file.puts 'Du bist ' + @param[:User]
	  file.puts 'Dein Passwort lautet: ' + @param[:Password]
	  file.puts 'Du willst in die Datenbank ' + @param[:databasetarget] 
	  file.puts 'Du hast den Organismus ' + @param[:Organism] + ' gew�hlt.'
	  file.puts 'Viel Spa� noch!'
	  end
	end
end

lk_Object = UploadAMSto2DB.new