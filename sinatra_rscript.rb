#!/usr/bin/ruby  

# file: sinatra_rscript.rb

require 'rubygems'
require 'sinatra'
require 'rcscript'
require 'rack/contrib'
use Rack::Evil


url_base = 'http://rorbuilder.info/r/heroku/' #
@@url_base = 'http://rorbuilder.info/r/heroku/' #
@@routes = {}
@@services = {}
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

def display_url_run(url, jobs, extension='.html')
  h = {'.xml' => 'text/xml','.html' => 'text/html','.txt' => 'text/plain'}
  @content_type = h[extension]

  out = run(url, jobs)

  content_type @content_type, :charset => 'utf-8' if defined? content_type
  out
end

def display_package_run(package_id, job, extension='.html')
  jobs = "//job:" + job
  url = "%s%s.rsf" % [@@url_base, package_id] 
  display_url_run(url,jobs, extension)
end

get '/' do
  redirect '/do/r/p/packages'             
end

get '/:alias' do
  url = url_base + "alias.xml?passthru=1"

  doc = Document.new(open(url, "UserAgent" => "Sinatra-Rscript").read)
  node = XPath.first(doc.root, "records/alias[name='#{params[:alias]}' and type='r']")
  pass unless node
  uri = node.text('uri').to_s

  redirect uri
end

get '/do/:package_id/:job' do
  package_id = params[:package_id] #
  job, extension = params[:job][/\.\w{3}$/] ? [$`, $&] : [params[:job], '.html']
  display_package_run(package_id, job, extension)
end

get '/view-source/:package_id/:job' do
  package_id = params[:package_id] #
  *jobs = params[:job] 

  url = "%s%s.rsf" % [url_base, package_id]
  buffer = open(url, "UserAgent" => 'Sinatra-Rscript').read
  content_type 'text/plain', :charset => 'utf-8'
  doc = Document.new(buffer)

  jobs.map!{|x| "@id='%s'" % x}
  doc.root.elements.to_a("//job[#{jobs.join(' or ')}]").map do |job|
    job.to_s
  end
end

get '/do/:package_id/:job/*' do
  h = {'.xml' => 'text/xml','.html' => 'text/html','.txt' => 'text/plain'}
  package_id = params[:package_id] #
  job, extension = params[:job][/\.\w{3}$/] ? [$`, $&] : [params[:job], '.html']
  jobs = "//job:" + job
  raw_args = params[:splat]
  args = raw_args.join.split('/')
  url = "%s%s.rsf" % [url_base, package_id] 
  @content_type = h[extension]
  result = run_rcscript(url, jobs)
  code = [result].flatten.join("\n")

  out = eval(code)
  content_type @content_type, :charset => 'utf-8'
  out

end

get '/view-source/:package_id' do
  package_id = params[:package_id] #
  url = "%s%s.rsf" % [url_base, package_id]
  buffer = open(url, "UserAgent" => 'Sinatra-Rscript').read
  content_type 'text/plain', :charset => 'utf-8'
  buffer
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
  run_projectx(project_name, method_name, request.params)
end


# projectx request
get '/p/projectx' do
  xml_project = request.params.to_a[0][1]
  projectx_handler(xml_project)
end

get '/load/:package_id/:job' do

  package_id = params[:package_id] #
  job, extension = params[:job][/\.\w{3}$/] ? [$`, $&] : [params[:job], '.html']
  load_rsf_job(package_id, job, route=package_id + '/' + job, extension)
end

helpers do

  def follow_route(key, route_type=:get)
    if @@routes.has_key? key and @@routes[key][:route] == route_type then
      @@routes[key][:proc].call(params)
    else
      route = @@routes.detect {|k,v| key[/#{k}/]}	    
      o = ($~)
      if o.is_a? MatchData then
        remaining = $'
        if remaining then
          args = remaining.split('/')
          args.shift
        else
          args = []
        end
        #a = o.captures

        route[1][:proc].call( params, args)
      else
        "no match"
      end
    end
  end

end


# custom routes
get '/*' do
  key = params[:splat].join
  out, @content_type = follow_route(key, :get)  
  @content_type ||= 'text/html'
  content_type @content_type, :charset => 'utf-8'
  out
end

post '/*' do
  key = params[:splat].join
  follow_route(key, :post)
end

configure do
  puts 'bootstrapping ... '
  # boot script
  Thread.new {
    doc = Document.new(File.open('server.xml','r').read)
    server_name = XPath.first(doc.root, 'summary/name/text()').to_s
    url = url_base + 'r.rsf'
    run(url, '//job:bootstrap', server_name)
  }
end
