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

get '/:package_id/:job' do
  url_base = 'http://leo.qbitx.com/r/'
  package_id = params[:package_id] #'hello'
  jobs = "//job:" + params[:job] #'//job:hello'
  buffer = run_rcscript(url_base + package_id + '.rsf', jobs)
  #buffer = run_rcscript()
  "<pre>%s</pre>" % buffer
end

get '/view-source/:package_id/' do
  #url_base = 'http://leo.qbitx.com/r/'
  url_base = 'http://rorbuilder.info/r/heroku/'
  package_id = params[:package_id] 

  url = "%s%s.rsf" % [url_base, package_id]
  buffer = open(url, "UserAgent" => 'Sinatra-Rscript').read
  content_type 'text/plain', :charset => 'utf-8'
  buffer

end

get '/view-source/:package_id/:job' do
  #url_base = 'http://leo.qbitx.com/r/'
  url_base = 'http://rorbuilder.info/r/heroku'
  package_id = params[:package_id] 
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
