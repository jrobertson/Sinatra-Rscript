#!/usr/bin/ruby  

# sinatra_rscript.rb
require 'rubygems'
require 'sinatra'
require 'rcscript'

def run_rcscript(rsf_url, jobs)
  thread = Thread.new{
    args = [jobs, rsf_url]
    rs = RScript.new()
    Thread.current[:out] = rs.run(args)
  }
  thread.join
  thread[:out]
end

#url_base = 'http://leo.qbitx.com/r/'
url_base = 'http://rorbuilder.info/r/heroku/' #

get '/:package_id/:job' do
  package_id = params[:package_id] #
  jobs = "//job:" + params[:job]
  url = "%s%s.rsf" % [url_base, package_id] 
  buffer = run_rcscript(url, jobs)
  "<pre>%s</pre>" % buffer
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
