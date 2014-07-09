ENV["LANG"]="en_US.UTF-8"
ENV["LC_CTYPE"]="en_US.UTF-8"
Encoding.default_internal = "UTF-8"
Encoding.default_external = "UTF-8"

require "./IdeoWebServer.rb"
run IdeoWebServer
