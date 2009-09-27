require 'sinatra_rscript'
require 'rack/contrib'
use Rack::Evil
run Sinatra::Application
