require "adif/version"
require "date"
require "strscan"
require "rexml/document"

class ADIF
  def self.parse_adi(adif)
	records = []

	s = StringScanner.new(adif)

	header = Header.new

	current = s.peek(1) == '<' ? Record.new : header
	until s.eos?
	  case
	  when s.scan(/[^<]*<(?<field>\w+):(?<length>\d+)(?::(?<type>.))?>/m)
		field, length, type = s[1].downcase, s[2].to_i, s[3] # StringScanner does not support named regexp
		value = s.peek(length)
		s.pos += length
		s.scan(/[^<]*/) # comment
		current[field, type] = value
	  when s.scan(/[^<]*<eoh>[^<]*/i)
		current = Record.new
	  when s.scan(/[^<]*<eor>[^<]*/i)
		records << current
		current = Record.new
	  else
		raise "unexpected string: #{s.string[s.pos..-1]}"
	  end
	end

	ADIF.new(header, records)
  end

  def self.parse_adx(adif)
	doc = REXML::Document.new(adif)
	header = Header.new

	header_e = doc.get_elements('/ADX/HEADER').first
	if header_e
	  header_e.each_element do |e|
		name = e.name
		if name == 'USERDEF'
		  name += e.attribute('FIELDID').value
		end
		type = e.attribute('TYPE').value rescue nil
		header[name.downcase, type] = e.text
	  end
	end

	records = []

	doc.each_element('/ADX/RECORDS/RECORD') do |record_e|
	  record = Record.new
	  record_e.each_element do |e|
		name = e.name
		case name
		when 'USERDEF'
		  name = e.attribute('FIELDNAME').value
		when 'APP'
		  name = "APP_%s_%s" % [ e.attribute('PROGRAMID').value, e.attribute('FIELDNAME')]
		end
		type = e.attribute('TYPE').value rescue nil
		record[name.downcase, type] = e.text
	  end
	  records << record
	end

	ADIF.new(header, records)
  end

  class Data
	attr_reader :fields

	def initialize(data={})
	  @fields = {}
	  @attributes  = {}

	  data.each do |k, v|
		k = k.intern
		case v
		when Array
		  @attributes[k] = v[0]
		  @fields[k]  = v[1]
		else
		  @fields[k]  = v.to_s
		end
	  end
	end

	def []=(name, type = nil, value)
	  @fields[name.intern] = value
	  @attributes[name.intern]  = type
	end

	def [](name)
	  @fields[name.intern]
	end

  end

  class Header < Data
  end

  class Record < Data
	def datetime_on
	  formats = [
		"%Y%m%d%H%M%S",
		"%Y%m%d%H%M",
		"%Y%m%d",
	  ]

	  begin
		DateTime.strptime("#{@fields[:qso_date]}#{@fields[:time_on]}", formats.shift)
	  rescue ArgumentError
		retry unless formats.empty?
	  end
	end

	def datetime_off
	  begin
		DateTime.strptime("#{@fields[:qso_date_off]}#{@fields[:time_off]}", "%Y%m%d%H%M%S")
	  rescue ArgumentError
		DateTime.strptime("#{@fields[:qso_date_off]}#{@fields[:time_off]}", "%Y%m%d%H%M")
	  end
	end
  end

  class Writer
	attr_reader :io

	def initialize(io, format = :adi)
	  @formatter = (format == :adx ? ADX : ADI).new
	  @io = io
	  @header = true

	  @io << @formatter.start
	end

	def <<(data)
	  case data
	  when Header
		if @header
		  @io << @formatter.header(data)
		  @header = false
		else
		  raise "already output records"
		end
	  when Record
		@header = false
		@io << @formatter.record(data)
	  else
		@io << data.to_s
	  end
	end

	def finish
	  @io << @formatter.finish
	end

	class Formatter
	  def start
		''
	  end

	  def header(data)
		''
	  end

	  def record(data)
		''
	  end

	  def finish
		''
	  end
	end

	class ADI < Formatter
	  def start
		"This is an ADIF file generated by ruby-adif.\n\n"
	  end

	  def header(data)
		data.fields.map {|k, v|
		  "<#{k.upcase}:#{v.size}>#{v}"
		}.join("\n") + "\n<EOH>\n\n"
	  end

	  def record(data)
		data.fields.map {|k, v|
		  "<#{k.upcase}:#{v.size}>#{v}"
		}.join("\n") + "\n<EOR>\n\n"
	  end
	end

	class ADX < Formatter
	  def start
		%|<?xml version="1.0" encoding="UTF-8"?>\n<ADX>\n|
	  end

	  def header(data)
		%|<HEADER>\n| +
		  data.fields.map {|k, v|
		  "<#{k.upcase}>#{xmlescape v}</#{k.upcase}>"
		}.join("\n") +
		  %|\n</HEADER>\n<RECORDS>\n|
	  end

	  def record(data)
		%|<RECORD>\n| +
		  data.fields.map {|k, v|
		  "<#{k.upcase}>#{xmlescape v}</#{k.upcase}>"
		}.join("\n") +
		  %|\n</RECORD>\n|
	  end

	  def finish
		%|</RECORDS>\n</ADX>|
	  end

	  XMLSPECIALS = {
		'<' => '&lt;',
		'>' => '&gt;',
		'&' => '&amp;',
		"'" => '&apos;',
		'"' => '&quot;',
	  }
	  def xmlescape(s)
		s.gsub(/[<>&'"]/, XMLSPECIALS)
	  end
	end
  end

  attr_reader :header, :records

  def initialize(header, records)
	@header  = header
	@records = records
  end
end
