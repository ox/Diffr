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
  output_text = ""
  hd = HTMLDiff.new(output_text)
  
  left = params[:left].to_s
  right = params[:right].to_s
  output_text << "<div style='width:100%;'><pre>"
  Diff::LCS.traverse_sequences(left, right, hd)
  output_text << "</pre></div>"
  return output_text
end

