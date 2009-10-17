#!/usr/bin/ruby  

# file: sinatra_rscript.rb
# update: 27-Sep-09

require 'rubygems'
require 'sinatra'
require 'rcscript'
require 'rack/contrib'
use Rack::Evil


url_base = 'http://rorbuilder.info/r/heroku/' #
@@routes = {}
@@services = {}
@@temp_route_id

def run_rcscript(rsf_url, jobs, arg='')
  args = [jobs, rsf_url, arg]
  rs = RScript.new()
  rs.run(args)
end

def run(url, jobs)
  result = run_rcscript(url, jobs)
  code = result.first.map {|x| x.first}.join
  eval(code)
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
  code = result.first.map {|x| x.first}.join(';')
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

get '/do/:package_id/:job/:arg1' do
  h = {'.xml' => 'text/xml','.html' => 'text/html','.txt' => 'text/plain'}
  package_id = params[:package_id] #
  job, extension = params[:job][/\.\w{3}$/] ? [$`, $&] : [params[:job], '.html']
  jobs = "//job:" + job
  *args = params[:arg1]
  url = "%s%s.rsf" % [url_base, package_id] 
  @content_type = h[extension]
  result = run_rcscript(url, jobs)
  code = result.first.map {|x| x.first}.join

  out = eval(code)
  content_type @content_type, :charset => 'utf-8'
  out

end

get '/view-source/:package_id/' do
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
    args = [jobs, rsf_url, arg]
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

  class App
    def initialize()
      @available = {}
      @running = {}
    end

    def load(app_name, handler_name)
    	@available[app_name] = handler_name
	    "'%s' loaded" % app_name
    end

    def run(app_name)
      if self.available? app_name then
        handler_name = @available[app_name]
	      @running[app_name] = eval(handler_name + "_handler.new")
	      return "'%s' running ..." % app_name
      else
      	return "app %s not available" % app_name
      end      
    end

    def execute(app_name, method, params='')
      @running[app_name].call(method, params)
    end

    def running?(app_name)
      @running.has_key? app_name
    end

    def available?(app_name)
    	@available.has_key? app_name
    end

    def stop(app_name)
      if @running.delete(app_name) then
	      return "app %s stopped" % app_name
      else
      	return "couldn't find app %s" % app_name
      end
    end

    def running()
    	@running.keys
    end

    def available()
    	@available.keys
    end

    def unload(app_name)
      handler_name = @available.delete(app_name)
      if handler_name then
        puts 'unhandle : ' + handler_name
        Object.send(:remove_const, handler_name + "_handler")
        Object.send(:remove_const, handler_name)
	      return "app %s unloaded" % app_name
      else
      	return "couldn't find app %s" % app_name
      end
    end

    def show_public_methods(app_name)
      if running? app_name 
        return @running[app_name].public_methods.grep(/call_/).map {|x| x.gsub(/call_/,'').gsub(/_/,'-')}.sort.join(', ')
      else
        return "app %s not running" % app_name
      end
    end
  end


  @@app = App.new

end

# projectx request
get '/p/:project_name/:method_name' do
  project_name = params[:project_name]
  method_name = params[:method_name]
  params = "<params>%s</params>" % request.params.map{|k,v| "<param var='%s'>%s</param>" % [k,v]}.to_s
  xml_project = project = "<project name='%s'><methods><method name='%s'>%s</method></methods></project>" % [project_name, method_name, params]
  projectx_handler(xml_project)
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
      o = ($~)
      if o.is_a? MatchData then
        a = o.captures
        route[1][:proc].call(a, params)
      else
        "no match"
      end
    end
  end

end

# custom routes
get '/*' do
  key = params[:splat].join
  follow_route(key)
end

post '/*' do
  key = params[:splat].join
  follow_route(key, :post)
end

# boot script
url = url_base + 'r.rsf'
run(url, '//job:bootstrap')
