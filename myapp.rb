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
