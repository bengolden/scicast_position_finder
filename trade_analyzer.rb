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
	end

	def to_tsv
		"#{@q_id}\t#{@q_name}\t#{@c_name}\t#{@assumption_q_id}\t#{@assumption_q_name}\t#{@assumption_c_name}\t#{@exposure}"
	end
end

class ScicastPosition
	@@position = []
	@@edits = []
	def self.parse_edits
		file = File.open(FILE)
		output = ""
		file.each do |line|
			output << line
		end
		raw_edits = JSON.parse(output)
		raw_edits.each do |edit|
			q_id = edit["question"]["id"]
			q_name = edit["question"]["name"].gsub(/[\n\t\r]/,"")
		  unless edit["assumptions"] == []
				assumption_q_id = edit["assumptions"][0]["id"]
				assumption_q_name = edit["assumptions"][0]["name"].gsub(/[\n\t\r]/,"")
				assumption_c_id = edit["assumptions"][0]["dimension"]
				assumption_choices = edit["assumptions"][0]["choices"]
				assumption_c_name = assumption_choices[assumption_c_id]["name"].gsub(/[\n\t\r]/,"")
			end
			edit["question"]["choices"].each_with_index do |choice, index|
			 	c_name = choice["name"].gsub(/[\n\t\r]/,"")
			 	exposure = edit["assets_per_option"][index].round(3)
			 	args = {q_id: q_id, 
			 					q_name: q_name, 
			 					c_name: c_name, 
			 					exposure: exposure,
			 					assumption_q_id: assumption_q_id, 
			 					assumption_q_name: assumption_q_name,
			 					assumption_c_name: assumption_c_name}
			 	@@edits << Position.new(args)
			end
		end
	end

	def self.aggregate_position
		@@edits.group_by{|edit| [edit.q_id, edit.q_name, edit.c_name, edit.assumption_q_id, edit.assumption_q_name, edit.assumption_c_name]}.each do |k,v|
			exposure = v.map{|edit| edit.exposure}.inject(:+).round(3)
			@@position << k + [exposure]
		end
	end

	def self.save_position_as_tsv
		IO.write('position.tsv',self.position_to_tsv)
	end

	def self.save_edits_as_tsv
		IO.write('edits.tsv',self.edits_to_tsv)
	end

	def self.edits_to_tsv
		output = "Question id\tQuestion name\tChoice name\tAssumption q id\tAssumption q name\tAssumption choice name\texposure\n"
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
# p ScicastPosition.edits_to_tsv
ScicastPosition.aggregate_position
ScicastPosition.save_edits_as_tsv
ScicastPosition.save_position_as_tsv