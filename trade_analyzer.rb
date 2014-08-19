require 'JSON'
FILE = 'trades.txt'

class Position
	attr_reader :q_id, :q_name, :c_name, :assumption_q_id, :assumption_q_name, :assumption_c_name, :exposure
	def initialize(args)
		@q_id = args[:q_id]
		@q_name = args[:q_name]
		@c_name = args[:c_name]
		@assumption_q_id = args[:assumption_q_id]
		@assumption_q_name = args[:assumption_q_name]
		@assumption_c_name = args[:assumption_c_name]
		@exposure = args[:exposure]
		@start_value = args[:start_value]
		@end_value = args[:end_value]
	end

	def to_tsv
		"#{@q_id}\t#{@q_name}\t#{@c_name}\t#{@assumption_q_id}\t#{@assumption_q_name}\t#{@assumption_c_name}\t#{@start_value}\t#{@end_value}\t#{@exposure}"
	end
end

class ScicastPosition
	@@position = []
	@@edits = []
	@@username = ""
	def self.parse_edits
		file = File.open(FILE)
		file_text = ""
		file.each do |line|
			file_text << line
		end
		raw_edits = JSON.parse(file_text)
		raw_edits.each do |edit|
			edit["question"]["choices"].each_with_index do |choice, index|
				exposure = edit["assets_per_option"][index].round(3)
				if exposure != 0 && edit["question"]["settled_values"] == nil
				 	args = {q_id: edit["question"]["id"], 
				 					q_name: edit["question"]["name"].gsub(/[\n\t\r]/,""), 
				 					c_name: choice["name"].gsub(/[\n\t\r]/,""),
				 					exposure: exposure,
				 					assumption_q_id: "#{edit["assumptions"][0]["id"] unless edit["assumptions"] == []}",
				 					assumption_q_name: "#{edit["assumptions"][0]["name"].gsub(/[\n\t\r]/,"") unless edit["assumptions"] == []}",
				 					assumption_c_name: "#{edit["assumptions"][0]["choices"][edit["assumptions"][0]["dimension"]]["name"].gsub(/[\n\t\r]/,"") unless edit["assumptions"] == []}",
				 					start_value: edit["old_value_list"][index].round(5),
				 					end_value: edit["new_value_list"][index].round(5)}
				 	@@edits << Position.new(args) 
				end
			end
		end
		# p raw_edits.last["old_value_list"]
		# p raw_edits.last["new_value_list"]
		@@username = raw_edits[0]["user"]["username"]
		@@date = Time.now.to_s[0..9]
	end

	def self.aggregate_position
		@@edits.group_by{|edit| [edit.q_id, edit.q_name, edit.c_name, edit.assumption_q_id, edit.assumption_q_name, edit.assumption_c_name]}.each do |k,v|
			exposure = v.map{|edit| edit.exposure}.inject(:+).round(3)
			@@position << k + [exposure]
		end
	end

	def self.save_position_as_tsv
		IO.write("#{@@username}-position-#{@@date}.tsv",self.position_to_tsv)
	end

	def self.save_edits_as_tsv
		IO.write("#{@@username}-edits-#{@@date}.tsv",self.edits_to_tsv)
	end

	private 

	def self.edits_to_tsv
		output = "Question id\tQuestion name\tChoice name\tAssumption q id\tAssumption q name\tAssumption choice name\tStart value\tEnd value\tExposure\n"
		@@edits.each {|edit| output << edit.to_tsv + "\n"}
		output
	end

	def self.position_to_tsv
		output = "Question id\tQuestion name\tChoice name\tAssumption q id\tAssumption q name\tAssumption choice name\texposure\n"
		@@position.each {|position| output << position.join("\t") + "\n"}
		output
	end
end

ScicastPosition.parse_edits
ScicastPosition.aggregate_position
ScicastPosition.save_edits_as_tsv
ScicastPosition.save_position_as_tsv