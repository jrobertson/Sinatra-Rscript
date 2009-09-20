#!/usr/bin/ruby  

# file: sinatra_rscript.rb
# update: 9-Sep-09

require 'rubygems'
require 'sinatra'
require 'rcscript'

def run_rcscript(rsf_url, jobs, arg='')
    args = [jobs, rsf_url, arg]
    rs = RScript.new()
    rs.run(args)

end

#url_base = 'http://leo.qbitx.com/r/'
url_base = 'http://rorbuilder.info/r/heroku/' #
@@projectx = {}    

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
  code = result.first.map {|x| x.first}.join
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

  def projectx_handler(xml_project)

    out = ''
    doc = Document.new(xml_project)
    project_name = doc.root.attribute('name').to_s

    if @@projectx.has_key? project_name then

	    out = XPath.match(doc.root, 'methods/method').map  do |node_method|
	      method = node_method.attributes.get_attribute('name').to_s
        puts method
	      params = node_method.elements['params'].to_s
        method_out = @@projectx[project_name].call(method, params)
        method_out
	    end
    else
      out = "that project doesn't exist"
    end
    out
  end
end

# projectx request
get '/p/:project_name/:method_name' do
  project_name = params[:project_name]
  method_name = params[:method_name]
  params = "<params>%s</params>" % request.params.map{|k,v| "<param var='%s'>%s</param>" % [k,v]}   
  xml_project = project = "<project name='%s'><methods><method name='%s'>%s</method></methods></project>" % [project_name, method_name, params]
  projectx_handler(xml_project)
end


# projectx request
get '/p/projectx' do
  xml_project = request.params.to_a[0][1]
  projectx_handler(xml_project)
end
