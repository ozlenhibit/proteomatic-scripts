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

require './include/ruby/misc'
require './include/ruby/externaltools'
require 'set'
require 'yaml'


class Parameters
	def initialize()
		@mk_Parameters = Hash.new
		@mk_ParametersOrder = Array.new
	end
	
	def addParameter(ak_Parameter, as_ExtTool = '', ab_GetInfoOnly = false)
		if (!ak_Parameter.has_key?('key') || ak_Parameter['key'].length == 0)
			puts "Internal error: Parameter has no key."
			exit 1
		end
		if (!ak_Parameter.has_key?('type'))
			puts "Internal error: Parameter #{ak_Parameter['key']} has no type."
			exit 1
		end
		if @mk_ParametersOrder.include?(ak_Parameter['key'])
			puts "Internal error: Parameter #{ak_Parameter['key']} already exists."
			exit 1
		end
		ls_Key = ak_Parameter['key']
		@mk_ParametersOrder.push(ls_Key)
		ak_Parameter['group'] = 'Parameters' if (!ak_Parameter.has_key?('group'))
		ak_Parameter['label'] = ls_Key if (!ak_Parameter.has_key?('label'))
		lk_FallbackDefaultValue = nil
		if (ak_Parameter.has_key?('valuesFromProgram'))
            if ab_GetInfoOnly
                return false
            else
                ls_Switch = ak_Parameter['valuesFromProgram']
                ls_Result = ''
                IO.popen("#{ExternalTools::binaryPath(as_ExtTool)} #{ls_Switch}") { |f| ls_Result = f.read }
                #puts ls_Result
                ak_Parameter['choices'] = Array.new
                ls_Result.each_line do |ls_Line|
                    lk_Line = ls_Line.split(':')
                    next if lk_Line.size != 2
                    # check whether key is a number
                    next if (lk_Line.first.strip =~ /^-?\d+$/) == nil
                    ak_Parameter['choices'].push({lk_Line[0].strip => lk_Line[1].strip})
                end
            end
		end
		if (ak_Parameter.has_key?('valuesFromConfig'))
            if ab_GetInfoOnly
                return false
            else
                lk_Config = ak_Parameter['valuesFromConfig']
                ak_Parameter['choices'] = ExternalTools::getToolConfig(lk_Config['tool'])[lk_Config['key']]
            end
		end
		case ak_Parameter['type']
		when 'bool' then
			lk_FallbackDefaultValue = false
		when 'int' then
			lk_FallbackDefaultValue = 0
		when 'float' then
			lk_FallbackDefaultValue = 0.0
		when 'string' then
			lk_FallbackDefaultValue = ''
		when 'enum' then
			lk_FallbackDefaultValue = ak_Parameter['choices'].first
			lk_FallbackDefaultValue = lk_FallbackDefaultValue.keys.first if lk_FallbackDefaultValue.class == Hash
		when 'flag' then
			lk_FallbackDefaultValue = false
		when 'csvString' then
			lk_FallbackDefaultValue = ''
		end
		ak_Parameter['default'] = lk_FallbackDefaultValue unless ak_Parameter.has_key?('default')
		if (ak_Parameter['enabled'])
			lk_NewExpression = Array.new
			lk_Expression = ak_Parameter['enabled']
			lk_Expression = [lk_Expression] unless lk_Expression.class == Array
			lk_NewExpression.push(Array.new)
			lk_Expression.each do |lk_SubExpression|
				lk_SubExpression = [lk_SubExpression] unless lk_SubExpression.class == Array
				lk_SubExpression.each do |ls_Expression|
					lk_NewExpression.last.push(ls_Expression)
				end
			end
			ak_Parameter['enabled'] = lk_NewExpression
		end
		@mk_Parameters[ls_Key] = ak_Parameter
		reset(ls_Key)
        return true
	end
	
	def keys()
		return @mk_ParametersOrder
	end
	
	def value(as_Key)
		return @mk_Parameters[as_Key]['value']
	end
	
	def humanReadableValue(as_Key, as_Value)
        lk_Parameter = @mk_Parameters[as_Key]
        ls_Value = '-'
		case lk_Parameter['type']
		when 'bool' then
			ls_Value = as_Value ? 'yes' : 'no'
		when 'int' then
			ls_Value = as_Value.to_s
            ls_Value += " #{lk_Parameter['suffix']}" if lk_Parameter.has_key?('suffix')
		when 'float' then
			ls_Value = as_Value.to_s
            ls_Value += " #{lk_Parameter['suffix']}" if lk_Parameter.has_key?('suffix')
		when 'string' then
			ls_Value = as_Value
		when 'enum' then
			as_Value = as_Value.to_s unless as_Value.class == String
			@mk_Parameters[as_Key]['choices'].each do |lk_Choice|
				ls_Key = lk_Choice.class == Hash ? lk_Choice.keys.first : lk_Choice
				ls_Key = ls_Key.to_s unless ls_Key.class == String
				next unless as_Value == ls_Key
				lk_Choice = lk_Choice.values.first if lk_Choice.class == Hash
				ls_Value = lk_Choice.to_s
			end
		when 'flag' then
			ls_Value = as_Value ? 'yes' : 'no'
		when 'csvString' then
			as_Value = as_Value.to_s unless as_Value.class == String
			lk_Value = as_Value.split(',')
			lk_Pretty = Array.new
			lk_Value.each_index { |i| lk_Value[i].strip! }
			@mk_Parameters[as_Key]['choices'].each do |lk_Choice|
				ls_Key = lk_Choice.class == Hash ? lk_Choice.keys.first : lk_Choice
				ls_Key = ls_Key.to_s unless ls_Key.class == String
				next unless lk_Value.include?(ls_Key)
				lk_Choice = lk_Choice.values.first if lk_Choice.class == Hash
				lk_Value[lk_Value.index(ls_Key)] = lk_Choice.to_s
			end
			ls_Value = lk_Value.join(', ')
            ls_Value = '-' if ls_Value.empty?
		end

		return ls_Value
	end
	
	def default?(as_Key)
		ls_Value = @mk_Parameters[as_Key]['value']
		ls_Default = @mk_Parameters[as_Key]['default']
		ls_Value = ls_Value.to_s unless ls_Value.class == String
		ls_Default = ls_Default.to_s unless ls_Default.class == String
		ls_Value = (ls_Value == 'true' || ls_Value == 'yes') ? 'yes' : 'no' if @mk_Parameters[as_Key]['type'] == 'flag'
		return ls_Value == ls_Default
	end
	
	def parameter(as_Key)
		return @mk_Parameters[as_Key]
	end
	
	def set(as_Key, ak_Value)
		case @mk_Parameters[as_Key]['type']
		when 'float' then
			@mk_Parameters[as_Key]['value'] = ak_Value.to_f
		when 'int' then
			@mk_Parameters[as_Key]['value'] = ak_Value.to_i
		when 'flag' then
			if (ak_Value == true || ak_Value == 'true' || ak_Value == 'yes')
				@mk_Parameters[as_Key]['value'] = true
			elsif (ak_Value == false || ak_Value == 'false' || ak_Value == 'no')
				@mk_Parameters[as_Key]['value'] = false
			else
				puts "Internal error: Invalid value for parameter #{as_Key}: #{ak_Value}."
				exit 1
			end
		when 'csvString' then
			lk_Values = Set.new(ak_Value.split(','))
			@mk_Parameters[as_Key]['choices'].each do |lk_Choice|
				if (lk_Choice.class == Hash)
					lk_Values -= [lk_Choice.keys.first]
				else
					lk_Values -= [lk_Choice]
				end
			end
			unless lk_Values.empty?
				puts "Error: Invalid value#{lk_Values.size == 1 ? '' : 's'} #{lk_Values.to_a.join(', ')}."
				exit(1)
			end
			@mk_Parameters[as_Key]['value'] = ak_Value
		else
			@mk_Parameters[as_Key]['value'] = ak_Value
		end
	end

	def reset(as_Key)
		set(as_Key, @mk_Parameters[as_Key]['default'])
	end
	
	def serialize(as_Key)
		ls_Result = ''
		ls_Result += "!!!begin parameter\n"
		@mk_Parameters[as_Key].each do |ls_Key, ls_Value|
            if (ls_Key == 'choices')
				lk_Choices = ls_Value
				ls_Result += "!!!begin values\n"
				lk_Choices.each do |lk_Choice|
					if lk_Choice.class == Hash
						ls_Result += "#{lk_Choice.keys.first}: #{lk_Choice[lk_Choice.keys.first]}\n"
					else
						ls_Result += "#{lk_Choice}\n"
					end
				end
				ls_Result += "!!!end values\n"
			else
				ls_Result += "#{ls_Key}\n#{ls_Value}\n"
            end
		end
		ls_Result += "!!!end parameter\n"
		return ls_Result
	end
	
    def parameterInfo(as_Key)
        result = Hash.new
        @mk_Parameters[as_Key].each do |ls_Key, ls_Value|
            if (ls_Key == 'choices')
                lk_Choices = ls_Value
                result['choices'] = Array.new
                lk_Choices.each do |lk_Choice|
                    if lk_Choice.class == Hash
                        result['choices'] << { lk_Choice.keys.first => lk_Choice[lk_Choice.keys.first] }
                    else
                        result['choices'] << lk_Choice
                    end
                end
            else
                result[ls_Key] = ls_Value
            end
        end
        return result
    end
    
	def helpString()
		ls_Result = ''
		lk_Groups = Array.new
		@mk_ParametersOrder.each do |ls_Key| 
			lk_Parameter = parameter(ls_Key)
			lk_Groups.push(lk_Parameter['group']) if !lk_Groups.include?(lk_Parameter['group'])
		end
		lk_Groups.each do |ls_Group|
			# print group title
			# but strip leading '{int}' !
			ls_CleanGroup = ls_Group.dup
			if ls_CleanGroup.index('{') == 0
				ls_CleanGroup.sub!(/\{\d+\}/, '')
			end
			ls_Result += "#{underline(ls_CleanGroup, '-')}\n"
			# print options
			@mk_ParametersOrder.each do |ls_Key|
				lk_Parameter = parameter(ls_Key)
				next if lk_Parameter['group'] != ls_Group
				ls_Line = "-#{ls_Key} "
				if (lk_Parameter.has_key?('choices'))
					lk_Choices = Array.new
					lk_Parameter['choices'].each do |lk_Detail|
						if lk_Detail.class == Hash
							lk_Choices.push("#{lk_Detail.keys.first}: #{lk_Detail.values.first}") if !(lk_Detail.keys.first.class == String && lk_Detail.keys.first.empty?)
						else
							lk_Choices.push(lk_Detail)
						end
					end
					ls_Line += "<#{lk_Choices.join(', ')}> (default: #{lk_Parameter['default']})"
				else
					ls_Line += "<#{lk_Parameter['type']}> (default: #{lk_Parameter['default']})"
				end
				ls_Result += "#{indent(wordwrap(ls_Line), 2, false).rstrip + "\n"}"
				ls_Explanation = (lk_Parameter.has_key?('description') ? lk_Parameter['description'] : lk_Parameter['label'])
				ls_Explanation = indent(wordwrap(ls_Explanation), 4)
				ls_Result += "#{ls_Explanation}\n"
			end
		end
		return ls_Result
	end
	
	def parametersString()
		ls_Result = ''
		@mk_ParametersOrder.each { |ls_Key| ls_Result += serialize(ls_Key) }
		return ls_Result
	end
	
    def yamlInfo()
        info = Array.new
        @mk_ParametersOrder.each { |ls_Key| info << parameterInfo(ls_Key) }
        return info
    end
    
	def humanReadableConfigurationHash()
		lk_Result = Array.new
		@mk_ParametersOrder.each { |ls_Key| lk_Result.push({@mk_Parameters[ls_Key]['label'] => humanReadableValue(ls_Key, value(ls_Key))}) }
		return lk_Result
	end
	
	def applyParameters(ak_Parameters)
		while (!ak_Parameters.empty?)
			ls_Key = ak_Parameters.first.dup
			if (ls_Key[0, 1] == '-')
				ls_Key.slice!(0)
				if (@mk_Parameters.include?(ls_Key))
					ak_Parameters.slice!(0)
					ls_Value = ak_Parameters.slice!(0)
					set(ls_Key, ls_Value)
				else
					break
				end
			else
				break
			end
		end
	end
	
	def commandLineFor(as_Program)
		ls_Result = ''
		@mk_Parameters.each do |ls_Key, lk_Parameter| 
			if ls_Key.index(as_Program) == 0
				if (lk_Parameter['type'] == 'flag')
					ls_Result += " #{lk_Parameter['commandLine']}" if lk_Parameter['value']
				else
					unless lk_Parameter['ignoreIfEmpty'] && lk_Parameter['value'].empty?
						lk_Value = lk_Parameter['value']
						if ['float', 'int'].include?(lk_Parameter['type'])
							if lk_Parameter['commandLineFactor']
								lk_Value *= lk_Parameter['commandLineFactor']
							end
						end
						if lk_Parameter['type'] == 'string'
							lk_Value = '"' + lk_Value + '"'
						end
						ls_Result += " #{lk_Parameter['commandLine']} #{lk_Value}"
 					end
				end
			end
		end
		return ls_Result
	end
	
	def checkSanity()
		@mk_Parameters.each do |ls_Key, lk_Parameter| 
			if (lk_Parameter['enabled'])
				lk_Parameter['enabled'].each do |lk_Expression|
					lk_Expression.each do |ls_Expression|
						@mk_Parameters.keys.each do |ls_ThisKey|
							ls_Expression.strip!
						end
					end
				end
			end
		end
	end
end
