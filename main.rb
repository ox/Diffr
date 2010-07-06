require 'json'
require 'diff/lcs'
require 'S3Setup'
require 'aws/s3'

AWS::S3::Base.establish_connection!(
  :access_key_id     => 'xxxxxxxxxxxxxxxx',
  :secret_access_key => 'xxxxxxxxxxxxxxxxxxxxxxxxx'
)

include AWS::S3
S3Object.set_current_bucket_to 'papercrate'

template :layout do
"%html
  = yield"
end

template :main do
"%h1 Upload

%form{:action=>\"/upload\",:method=>\"post\",:enctype=>\"multipart/form-data\"}
  %input{:type=>\"file\",:name=>\"file\"}
  %input{:type=>\"submit\",:value=>\"Upload\"}"
end

class ChangeSet
  attr_accessor :array, :version
  
  def initialize(arr, ver)
    self.array = arr
    self.version = ver
  end
  
  def self.to_s
    "#{version}: #{array}\n"
  end
end

get '/' do
  #login_required
  haml :main
end

get '/files' do
  data = ''
  Bucket.objects('papercrate').each do |object|
    key = object.key.gsub(/user\//,"")
    data += "<a href=#{S3Object.url_for(key, 'papercrate', :use_ssl => true) }'>#{key}</a><br/>"
  end
  #replace anything in a diff dir with nothing
  haml data.gsub( /<a href=\'(?:\w.*?)>(?=diffs\/)(.*?)<\/a><br\/>/, "")
end

get '/clone/*' do |name|
  puts "serving: #{name}"
  S3Object.value "user/#{name}"
end

get '/version/*' do |name|
  curr_diffs = []

  #append diff to file change history
  if S3Object.exists? "user/diffs/#{name}.diffs"
    curr_diffs = Marshal.load(S3Object.value("user/diffs/#{name}.diffs"))
  end
  
  {"version" => curr_diffs.size}.to_json
end

get '/get/v*/*' do |version,name|
  curr_diffs = []

  #append diff to file change history
  if S3Object.exists? "user/diffs/#{name}.diffs"
    curr_diffs = Marshal.load(S3Object.value("user/diffs/#{name}.diffs"))
  end
  
  text = S3Object.value("user/#{name}").gsub( /\A"/m, "" ).gsub( /"\Z/m, "" ).to_s
  if curr_diffs.size == 0
    {"name"=>name, "version" => 0, "text"=> text}.to_json
  end
  
  if curr_diffs.size == version
    {"name"=>name, "version" => version, "text"=> text}.to_json
  else
    to_patch = []
    
    curr_diffs.each do |changeset|
      if changeset.version >= version.to_i()
        to_patch << changeset
      end
    end
    
    to_patch.reverse!()
    to_patch.each do |changeset|
      Diff::LCS.unpatch!(text, changeset.array)
    end
    
    {"name"=>name, "version" => version, "text"=>text}.to_json
  end
end

post '/upload' do
  #if not
  unless params[:file] &&
         (tmpfile = params[:file][:tempfile]) &&
         (name = params[:file][:filename].gsub( /\A"/m, "" ).gsub( /"\Z/m, "" )) &&
    @error = "No file selected!"
    haml(:main)
  end
  STDERR.puts "Uploading file, original name #{name}"
    
  while blk = tmpfile.read(65536)
      if S3Object.exists? "user/#{name}"
        STDERR.puts "user/#{name} exists, versioning"
      
        #get the contents of the file at its current HEAD
        head = S3Object.value("user/#{name}")
        head = head.gsub( /\A"/m, "" ).gsub( /"\Z/m, "" )
        
        if head != blk
          #get the diff between pushed and HEAD
          diffs = Diff::LCS.diff(head, blk)
          
          curr_diffs = []
      
          #append diff to file change history
          if S3Object.exists? "user/diffs/#{name}.diffs"
            curr_diffs = Marshal.load(S3Object.value("user/diffs/#{name}.diffs"))
          end
          
          changes = ChangeSet.new(diffs, curr_diffs.size)
          curr_diffs << changes
                            
          S3Object.store "user/diffs/#{name}.diffs", Marshal.dump(curr_diffs)
          
          #write it back to the file
          S3Object.store "user/#{name}", blk
          {"new_version"=>curr_diffs.size-1}.to_json
        else
          {"status"=>"no difference"}.to_json
        end
      else
        puts "wrote file user/#{name}" if S3Object.store "user/#{name}", blk
        {"new_version"=>0}.to_json
      end
    #STDERR.puts blk.inspect
  end
end

post '/destroy/*' do |name|
  S3Object.delete "user/#{name}"
  S3Object.delete "user/diffs/#{name}.diffs"
  {"name"=>name, "status"=>"deleted"}.to_json unless (S3Object.exists? "user/#{name}") && 
                                                     (S3Object.exists? "user/diffs/#{name}.diff")
end
