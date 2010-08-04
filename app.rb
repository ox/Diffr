#require 'activate_db'
require 'erb'
require 'diff/lcs'
require 'diff/lcs/hunk'
require 'diff/lcs/string'
require 'uri'

class HTMLDiff
  attr_accessor :output

  def initialize(output)
    @output = output
  end

    # This will be called with both lines are the same
  def match(event)
    @output << event.old_element.to_s
  end

    # This will be called when there is a line in A that isn't in B
  def discard_a(event)
    @output << "<span class='only_a'>#{event.old_element.to_s}</span>"
  end

    # This will be called when there is a line in B that isn't in A
  def discard_b(event)
    @output << "<span class='only_b'>#{event.new_element.to_s}</span>"
  end
end

get '/' do
  erb :index
end



post '/diff' do
  data_old = params[:left].to_s.split(/\n/).map! { |e| e.chomp }
  data_new = params[:right].to_s.split(/\n/).map! { |e| e.chomp }
  
  diffs = Diff::LCS.diff(data_old, data_new)
  diffs = nil if diffs.empty?
  
  return "No Difference" unless diffs
   
  oldhunk = hunk = nil
  @format ||= :old
  @lines  ||= 0
  output = ""
  file_length_difference = 0
  
  case @format
  when :context
    char_old = '*' * 3
    char_new = '-' * 3
  when :unified
    char_old = '-' * 3
    char_new = '+' * 3
  end
  
  diffs.each do |piece|
    begin
      hunk = Diff::LCS::Hunk.new(data_old, data_new, piece, @lines,
                                 file_length_difference)
      file_length_difference = hunk.file_length_difference

      next unless oldhunk

      if (@lines > 0) and hunk.overlaps?(oldhunk)
        hunk.unshift(oldhunk)
      else
        output << oldhunk.diff(@format) 
      end
    ensure
      oldhunk = hunk
      output << "<br/>"
    end
  end

  output << oldhunk.diff(@format)
  output << "<br/>"

  return output.gsub(/"(.*?)<br\/>(.*?)"/, "\"&lt;br/&gt;\"").gsub(/"(.*?)<pre>(.*?)"/, "\"&lt;pre&gt;\"")
end
