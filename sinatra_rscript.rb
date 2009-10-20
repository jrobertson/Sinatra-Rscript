#!/usr/bin/ruby  

# file: sinatra_rscript.rb

require 'rubygems'
require 'sinatra'
require 'rcscript'
require 'rack/contrib'
use Rack::Evil


url_base = 'http://rorbuilder.info/r/heroku/' #
@@routes = {}
@@services = {}
@content_type = 'text/html'

def run_rcscript(rsf_url, jobs, arg='')
  ajobs = jobs.split(/\s/)
  args = [rsf_url, ajobs, arg].flatten
  rs = RScript.new()
  rs.run(args)
end

def run(url, jobs, qargs=[])
  result, args = run_rcscript(url, jobs, qargs)
  code = [result].flatten.join("\n")
  eval(code)
end

def projectx_handler(xml_project)

  out = ''
  doc = Document.new(xml_project)
  project_name = doc.root.attribute('name').to_s

  if @@app.running? project_name then

    out = XPath.match(doc.root, 'methods/method').map  do |node_method|
      method = node_method.attributes.get_attribute('name').to_s
      puts method
      params = node_method.elements['params'].to_s
      method_out, @content_type = @@app.execute(project_name, method, params)
      method_out
    end
  else
    out = "that project doesn't exist"
  end
  @content_type ||= 'text/xml'

  content_type @content_type, :charset => 'utf-8' if defined? content_type
  out
end

def run_projectx(project_name, method_name, qparams=[])
  params = "<params>%s</params>" % qparams.map{|k,v| "<param var='%s'>%s</param>" % [k,v]}.to_s
  xml_project = project = "<project name='%s'><methods><method name='%s'>%s</method></methods></project>" % [project_name, method_name, params]
  projectx_handler(xml_project)
end



get '/' do
  redirect '/do/r/p/packages'             
end

get '/:alias' do
  url = url_base + "alias.xml?passthru=1"

  doc = Document.new(open(url, "UserAgent" => "Sinatra-Rscript").read)
  uri = XPath.first(doc.root, "records/alias[name='#{params[:alias]}']/uri/text()")
  redirect uri.to_s
end

get '/do/:package_id/:job' do
  h = {'.xml' => 'text/xml','.html' => 'text/html','.txt' => 'text/plain'}
  package_id = params[:package_id] #
  job, extension = params[:job][/\.\w{3}$/] ? [$`, $&] : [params[:job], '.html']
  jobs = "//job:" + job
  url = "%s%s.rsf" % [url_base, package_id] 
  @content_type = h[extension]
  result = run_rcscript(url, jobs)

  # get the code
  code = [result].flatten.join("\n")
  out = eval(code)

  content_type @content_type, :charset => 'utf-8'
  out
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
    rs.run(args)
  end

  def projectx_handler(xml_project)

    out = ''
    doc = Document.new(xml_project)
    project_name = doc.root.attribute('name').to_s

    if @@app.running? project_name then

	    out = XPath.match(doc.root, 'methods/method').map  do |node_method|
	      method = node_method.attributes.get_attribute('name').to_s
        puts method
	      params = node_method.elements['params'].to_s
        method_out, @content_type = @@app.execute(project_name, method, params)
        method_out
	    end
    else
      out = "that project doesn't exist"
    end
    @content_type ||= 'text/xml'

    content_type @content_type, :charset => 'utf-8'
    out
  end


  def run_projectx(project_name, method_name, qparams=[])
    params = "<params>%s</params>" % qparams.map{|k,v| "<param var='%s'>%s</param>" % [k,v]}.to_s
    xml_project = project = "<project name='%s'><methods><method name='%s'>%s</method></methods></project>" % [project_name, method_name, params]
    projectx_handler(xml_project)
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

helpers do

  def follow_route(key, route_type = :get)
    if @@routes.has_key? key and @@routes[key][:route] == route_type then
      @@routes[key][:proc].call(params)
    else
      route = @@routes.detect {|k,v| key[/#{k}/]}	    
      puts 'route : ' + route.to_s
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

get '/load/:package_id/:job' do

  package_id = params[:package_id] #
  job, extension = params[:job][/\.\w{3}$/] ? [$`, $&] : [params[:job], '.html']
  jobs = "//job:" + job
  url = "%s%s.rsf" % [url_base, package_id] 

  result = run_rcscript(url, jobs)

  # get the code
  code = [result].flatten.join("\n")
  proc1 = Proc.new {|params, args|
    h = {'.xml' => 'text/xml','.html' => 'text/html','.txt' => 'text/plain'}
    @content_type = h[extension]

    out = eval(code)

    [out, @content_type]
  }
  route = "%s/%s" % [package_id, job]
  @@routes[route] = {:route => :get, :proc => proc1}
  content_type 'text/plain', :charset => 'utf-8'

  'job loaded'
end

get '/load/:package_id/:job/*' do

  package_id = params[:package_id] #
  *args = params[:splat]
  job, extension = params[:job][/\.\w{3}$/] ? [$`, $&] : [params[:job], '.html']
  jobs = "//job:" + job
  url = "%s%s.rsf" % [url_base, package_id] 

  result = run_rcscript(url, jobs)

  # get the code
  code = [result].flatten.join('\n')
  proc1 = Proc.new {|params, *args|

    h = {'.xml' => 'text/xml','.html' => 'text/html','.txt' => 'text/plain'}
    @content_type = h[extension]

    out = eval(code)

    [out, @content_type]
  }
  route = "%s/%s" % [package_id, job]
  @@routes[route] = {:route => :get, :proc => proc1}
  content_type 'text/plain', :charset => 'utf-8'
  #out
  'job loaded'
end

# custom routes
get '/*' do
  key = params[:splat].join
  out, @content_type = follow_route(key)  
  @content_type ||= 'text/html'
  content_type @content_type, :charset => 'utf-8'
  out
end

post '/*' do
  key = params[:splat].join
  follow_route(key, :post)
end

# boot script
doc = Document.new(File.open('server.xml','r').read)
server_name = XPath.first(doc.root, 'summary/name/text()').to_s
url = url_base + 'r.rsf'
run(url, '//job:bootstrap', server_name)
