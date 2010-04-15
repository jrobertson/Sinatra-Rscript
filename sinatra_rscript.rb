#!/usr/bin/ruby  

# file: sinatra_rscript.rb

require 'rubygems'
require 'sinatra'
require 'rcscript'
require 'rack/contrib'
require 'haml'

use Rack::Evil

url_base = 'http://rorbuilder.info/r/heroku/' #
@@url_base = 'http://rorbuilder.info/r/heroku/' #
@@get_routes = {}; @@post_routes = {}
@@services = {}
@@templates = {}
@content_type = 'text/html'

def run_rcscript(rsf_url, jobs, arg='')
  ajobs = jobs.split(/\s/)
  args = [rsf_url, ajobs, arg].flatten
  rs = RScript.new()
  rs.run(args)
end

def run(url, jobs, qargs='')
  result, args = run_rcscript(url, jobs, qargs)
  eval(result)
end

def display_url_run(url, jobs, opts)
  h = {'.xml' => 'text/xml','.html' => 'text/html','.txt' => 'text/plain'}
  @content_type = h[opts[:extension]]    
  out = run(url, jobs, opts[:args])

  content_type @content_type, :charset => 'utf-8' if defined? content_type
  out
end

def remote_file_code(url)
  url = URI.parse(url)
  Net::HTTP.start(url.host, url.port) do |http|
    return http.head(url.request_uri).code
  end
end

def package_run(package_id, job, opts={})
  o = {
    :extension => '.html',
    :args => []
  }.merge(opts)
  jobs = "//job:" + job

  url = run_projectx('registry', 'get-key', :path => "system/packages/*[name='#{package_id}']/url/text()")
  if url then
    display_url_run(url.to_s.sub(/^http:\/\/rscript.rorbuilder.info\//,'\0s/open/'),jobs, o)
  else

    code = remote_file_code(url)

    if code == '200' then
      url = "%s%s.rsf" % [@@url_base, package_id] 
      display_url_run(url,jobs, o)
    else
      # 404
      url = url_base + 'open-uri-error.rsf'
      run(url, '//job:with-code', code)
    end
  end

end

get '/' do
  uri = run_projectx('registry', 'get-key', :path => 'system/homepage/uri/text()').to_s
  redirect(uri)  
end

get '/:alias' do
  url = run_projectx('registry', 'get-key', :path => 'system/uri_aliases/url/text()').to_s.clone
  puts 'uuuurrrrllll : ' + url
  url.sub!('http://rscript.rorbuilder.info/','\0s/open/')
  doc = Document.new(open(url, "UserAgent" => "Sinatra-Rscript").read)
  
  #url = @@url_base + "alias.xml?passthru=1"
  #doc = Document.new(open(url, "UserAgent" => "Sinatra-Rscript").read)
  node = XPath.first(doc.root, "records/alias[name='#{params[:alias]}' and type='r']")
  pass unless node
  uri = node.text('uri').to_s

  redirect uri
end

get '/css/:css' do

  css = params[:css]
  key = 'css/' + css

  if @@get_routes.has_key? key then
    out, @content_type = @@get_routes[key].call(params)
    @content_type ||= 'text/css'
    content_type @content_type, :charset => 'utf-8'
    out
  else
    rsf_job = run_projectx('registry', 'get-key', :path => "system/css/*[name='css/#{css}']/rsf_job/text()")
    if rsf_job then
      redirect rsf_job.to_s 
    else
      # 404
    end
  end
end


get '/:form/form' do

  form = params[:form]
  key = form + '/form'

  if @@get_routes.has_key? key then
    out, @content_type = @@get_routes[key].call(params)
    @content_type ||= 'text/html'
    content_type @content_type, :charset => 'utf-8'
    out
  else
    rsf_job = run_projectx('registry', 'get-key', :path => "system/forms/*[name='#{form}/form']/rsf_job/text()")
    if rsf_job then
      puts 'job found'
      redirect rsf_job.to_s 
    else
      # 404
    end
  end
end

get '/:form/form/*' do

  form = params[:form]
  key = form + '/form'
  args = params[:splat]

  if @@get_routes.has_key? key then
    out, @content_type = @@get_routes[key].call(params, args)
    @content_type ||= 'text/html'
    content_type @content_type, :charset => 'utf-8'
    out
  else
    rsf_job = run_projectx('registry', 'get-key', :path => "system/forms/*[name='#{form}/form']/rsf_job/text()")
    if rsf_job then
      file_path = args.length > 0 ? '/' + args.join('/') : ''
      puts 'form file_path : ' + file_path.to_s
      redirect rsf_job.to_s  + file_path
    else
      # 404
    end
  end
end

get '/do/:package_id/:job' do
  package_id = params[:package_id] #
  job, extension = params[:job][/\.\w{3}$/] ? [$`, $&] : [params[:job], '.html']
  package_run(package_id, job, {:extension => extension})
end

get '/view-source/:package_id/:job' do
  package_id = params[:package_id] #
  *jobs = params[:job] 

  #url = "%s%s.rsf" % [url_base, package_id]
  url = run_projectx('registry', 'get-key', :path => "system/packages/*[name='#{package_id}']/url/text()")
  if url then

    #redirect rsf_job.to_s 
    buffer = open(url.to_s.sub(/^http:\/\/rscript.rorbuilder.info\//,'\0s/open/'), "UserAgent" => 'Sinatra-Rscript').read
    content_type 'text/plain', :charset => 'utf-8'
    doc = Document.new(buffer)

    jobs.map!{|x| "@id='%s'" % x}
    doc.root.elements.to_a("//job[#{jobs.join(' or ')}]").map do |job|
      job.to_s
    end
  end


end

get '/do/:package_id/:job/*' do
  h = {'.xml' => 'text/xml','.html' => 'text/html','.txt' => 'text/plain'}
  package_id = params[:package_id] #
  job, extension = params[:job][/\.\w{3}$/] ? [$`, $&] : [params[:job], '.html']
  jobs = "//job:" + job
  raw_args = params[:splat]
  args = raw_args.join.split('/')

  package_run(package_id, job, {:extension => extension, :args => args})

end

get '/view-source/:package_id' do
  package_id = params[:package_id] #
  #url = "%s%s.rsf" % [url_base, package_id]
  url = run_projectx('registry', 'get-key', :path => "system/packages/*[name='#{package_id}']/url/text()")
  if url then
    buffer = open(url.to_s.sub(/^http:\/\/rscript.rorbuilder.info\//,'\0s/open/'), "UserAgent" => 'Sinatra-Rscript').read
    content_type 'text/plain', :charset => 'utf-8'
    buffer
  end
end

get '/do/:package_id/' do
  redirect "/do/r/p/" + params[:package_id]
end

helpers do

  def run_rcscript(rsf_url, jobs, arg='')
    ajobs = jobs.split(/\s/)
    args = [rsf_url, ajobs, arg].flatten
    rs = RScript.new()
    out = rs.run(args)
    out
  end

end

# projectx request
get '/p/:project_name/:method_name' do
  project_name = params[:project_name]
  method_name = params[:method_name]
  r = run_projectx(project_name, method_name, request.params)
  # todo: implement a filter to check for rexml objects to be converted to a string
  r
end


# projectx request
get '/p/projectx' do
  xml_project = request.params.to_a[0][1]
  projectx_handler(xml_project)
end

get '/load/:package_id/:job' do

  package_id = params[:package_id] #
  job, extension = params[:job][/\.\w{3}$/] ? [$`, $&] : [params[:job], '.html']
  load_rsf_job2(package_id, job, route=package_id + '/' + job, extension)
end

helpers do

  def follow_route(routes, key)
    if routes.has_key? key then
      routes[key].call(params)
    else
      route = routes.detect {|k,v| key[/#{k}/]}

      if route then
        remaining = $'
        if remaining then
          args = remaining.split('/')
          args.shift
        else
          args = []
        end

        route[1].call( params, args)
      else
        puts 'preparing to view file' + key.inspect

	out = run_projectx('dir', 'view', {:file_path => key, :passthru => params[:passthru]})
	[out, @content_type]
        #puts "no match"
      end
    end
  end
end


# custom routes
get '/*' do
  key = params[:splat].join

  if params.has_key? 'edit' and params[:edit] = '1' then
    # fetch the editor
    # we first need to know the file type
    # open the xml file
    url = @@url_base + key
    buffer = open(url.to_s.sub(/^http:\/\/rscript.rorbuilder.info\//,'\0s/open/'), "UserAgent" => 'Sinatra-Rscript').read
    doc = Document.new(buffer)
    recordx_type = XPath.first(doc.root, 'summary/recordx_type/text()').to_s
    uri = run_projectx('registry', 'get-key', :path => "system/recordx_editor/#{recordx_type}/uri/text()").to_s
    editor_url = @@url_base + uri + '/' + key

    redirect editor_url
  else
  
    out, content_type = follow_route(@@get_routes, key)  
    #puts out
    puts 'Content type : ' + content_type unless content_type.nil?
    content_type ||= 'text/html'
    content_type 	content_type, :charset => 'utf-8'
    out
  end
end

post '/*' do
  key = params[:splat].join
  out, content_type = follow_route(@@post_routes, key)
  #puts 'sss' + out.to_s
  #out = follow_route(@@post_routes, key)
  content_type ||= 'text/html'
  content_type  content_type, :charset => 'utf-8'  
  out
end

configure do
  puts 'bootstrapping ... '
  # boot script
  Thread.new {
    doc = Document.new(File.open('server.xml','r').read)
    server_name = XPath.first(doc.root, 'summary/name/text()').to_s
    #url = url_base + 'startup.rsf'
    url = url_base + 'startup-level1.rsf'
    run(url, '//job:bootstrap', server_name)
  }
end
