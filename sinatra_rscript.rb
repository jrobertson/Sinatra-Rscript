#!/usr/bin/ruby  

# file: sinatra_rscript.rb
# update: 5-Sep-09

require 'rubygems'
require 'sinatra'
require 'rcscript'

def run_rcscript(rsf_url, jobs, arg='')
  thread = Thread.new{
    args = [jobs, rsf_url, arg]
    rs = RScript.new()
    Thread.current[:out] = rs.run(args)
  }
  thread.join
  thread[:out]
end

#url_base = 'http://leo.qbitx.com/r/'
url_base = 'http://rorbuilder.info/r/heroku/' #

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
  code = run_rcscript(url, jobs)
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
  code = run_rcscript(url, jobs, arg)
  puts code
  #eval(code)
  "hi"
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
  doc.root.elements.to_a("//job[#{jobs.join(' or ')}]").map do |job|
    job.to_s
  end
end
