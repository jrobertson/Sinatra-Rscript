#!/usr/bin/ruby  

# file: sinatra_rscript.rb
# update: 5-Sep-09

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

get '/' do
  package_id = 'r'
  job = 'p'
  jobs = "//job:" + job
  arg = 'packages'
  url = "%s%s.rsf" % [url_base, package_id] 
  content_type 'text/html', :charset => 'utf-8'
  result = run_rcscript(url, jobs, arg)
  result.inspect
  code, args = result
  eval(code)
end

get '/:alias' do
  url = url_base + "alias.xml?passthru=1"

  doc = Document.new(open(url, "UserAgent" => "Sinatra-Rscript").read)
  uri = XPath.first(doc.root, "records/alias[name='#{params[:alias]}']/uri/text()")
  puts uri.to_s
  redirect uri.to_s
end

get '/:package_id/:job' do
  h = {'.xml' => 'text/xml','.html' => 'text/html','.txt' => 'text/plain'}
  package_id = params[:package_id] #
  job, extension = params[:job][/\.\w{3}$/] ? [$`, $&] : [params[:job], '.html']
  jobs = "//job:" + job
  url = "%s%s.rsf" % [url_base, package_id] 
  content_type h[extension], :charset => 'utf-8'
  result = run_rcscript(url, jobs)
  code, args = result
  eval(code)
end

get '/:package_id/:job/:arg1' do
  h = {'.xml' => 'text/xml','.html' => 'text/html','.txt' => 'text/plain'}
  package_id = params[:package_id] #
  job, extension = params[:job][/\.\w{3}$/] ? [$`, $&] : [params[:job], '.html']
  jobs = "//job:" + job
  arg = params[:arg1]
  url = "%s%s.rsf" % [url_base, package_id] 
  content_type h[extension], :charset => 'utf-8'
  result = run_rcscript(url, jobs, arg)
  code, args = result
  puts code.inspect
  eval(code)
  #"hi"
end

get '/view-source/:package_id/' do
  package_id = params[:package_id] #
  url = "%s%s.rsf" % [url_base, package_id]
  buffer = open(url, "UserAgent" => 'Sinatra-Rscript').read
  content_type 'text/plain', :charset => 'utf-8'
  buffer
end

get '/view-source/:package_id/:job' do
  package_id = params[:package_id] #
  *jobs = params[:job] 

  url = "%s%s.rsf" % [url_base, package_id]
  buffer = open(url, "UserAgent" => 'Sinatra-Rscript').read
  content_type 'text/plain', :charset => 'utf-8'
  doc = Document.new(buffer)

  jobs.map!{|x| "@id='%s'" % x}
  out = doc.root.elements.to_a("//job[#{jobs.join(' or ')}]").map do |job|
    job.to_s
  end
  out.join("\n")
end

