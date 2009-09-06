#!/usr/bin/ruby
#file: rcscript_base.rb

# created: 24-Aug-2009
# updated: 24-Aug-2009

require 'cgi'
require 'open-uri'
require 'rexml/document'
include REXML

class RScriptBase

  def initialize()
  end
  
  def run(doc)
    doc.root.elements.to_a('//script').map {|s| run_script(s)}.join
  end
  
  protected
  
  def run_script(script, args=[])  
    out_buffer = ''
    src = script.attribute('src')
    if src then
      out_buffer = read_sourcecode(script.attribute('src').value)
    else
      code = script.text.to_s.strip.length > 0 ? script.text : script.cdatas.join.strip
      out_buffer = code
    end
    [out_buffer, args]
  end
        
  def read_sourcecode(rsf)
    if rsf[/http:\/\//] then
      return open(rsf, "UserAgent" => "Ruby-SourceCodeReader").read
    else
      return File.open(rsf,'r').read
    end
  end          
  
end

