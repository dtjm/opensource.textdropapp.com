# This is a one-file Sinatra app backend for [TextDrop](http://textdropapp.com),
# an online text editor for Dropbox.
#
# by Sam Nguyen <<sam.nguyen@textdropapp.com>>

# Various require's
require 'date'
require 'dropbox'
require 'haml'
require 'htmlentities'
require 'json'
require 'sinatra/base'
require 'sinatra/url_for'
require 'sass'

# Library for check the *blankness* of objects
require './lib/blank'

# App configuration
# -----------------

# App version
TD_VERSION='2.2.4'

# Dropbox API auth
APIKEY='APIKEY'
APISECRET='APISECRET'

# TextDrop::Application
# ---------------------

# Uses the modular Sinatra app style
module TextDrop
  class Application < Sinatra::Base

    # Add helpers to the class scope
    helpers Sinatra::UrlForHelper

    # Turn on sessions
    enable :sessions

    # Turn on static file handling and point it to the `/public` directory in
    # the Sinatra app root folder
    enable :static
    set :public_folder, File.dirname(__FILE__) + '/public'

    # /
    # Just displays the index.haml template
    get '/' do
      @path = ""
      @title = "Online text editor for Dropbox"
      haml :index
    end

    # /edit
    # Handles editing new and existing files
    get '/edit' do
      haml :edit
    end

    # /login
    # If the HTTP param `oauth_token` is given, then this is being called back
    # after the Dropbox OAuth authorization.  In that case, save the OAuth
    # session and redirect the user to the `/new` route
    #
    # Otherwise, this is being called from a fresh login.  Redirect to the
    # Dropbox OAuth page
    get '/login' do

      if params[:oauth_token]
        db_session = Dropbox::Session.deserialize session[:dropboxSession]
        db_session.authorize
        db_session.enable_memoization
        session[:dropboxSession] = db_session.serialize
        redirect '/#new'

      else
        db_session = Dropbox::Session.new APIKEY, APISECRET, :ssl => false
        session[:dropboxSession] = db_session.serialize
        authorize_url = db_session.authorize_url :oauth_callback => url_for("/login", :full)
        authorize_url.gsub! /^https/, "http"
        redirect  authorize_url

      end
    end

    # Route for `logout`
    # ------------------

    # Empty dropbox session and render logout page
    get '/logout' do
      session[:dropboxSession] = nil
      @title = "Log out"
      haml :logout
    end

    # Route for `/browse`
    # -------------------

    # This route is used for fetching the contents of a directory
    get '/browse/*' do

      # If this is an ajax request and the session is invalid, send a special
      # `NOTLOGGEDIN` response
      if request.xhr? && session[:dropboxSession].nil?
        data = {:status => "NOTLOGGEDIN"}
        return JSON.generate data
      end

      # If the session is invalid, then just redirect the browser
      redirect "/login" if session[:dropboxSession].nil?
      db_session = Dropbox::Session.deserialize session[:dropboxSession]
      db_session.mode = :metadata_only

      # extract the path
      path = params[:splat][0]

      # Get the Dropbox object for the directory
      @dir = db_session.dir path

      # If it's an ajax request, then send a response with the directory
      # contents
      if request.xhr?
        files = []

        begin
          @dir.list.each { |f| files << f.to_hash }

        # If there's a Dropbox authorization error, send an appropriate response
        # to the client
        rescue Dropbox::UnauthorizedError
          data = {:status => "NOTLOGGEDIN"}
          return JSON.generate data
        end

        data = {
          :dirname => path,
          :files   => files
        }

        JSON.generate data

      # If it's not an ajax request, then just render the browse page
      else
        @title = "Open a file"
        haml :browse
      end
    end

    # Route for `GET /file`
    # -----------------

    # Handles both ajax and non-ajax requests to open a file
    get '/file/*' do
      db_session = Dropbox::Session.deserialize session[:dropboxSession]

      db_session.mode = :metadata_only

      filePathName = params[:splat][0]

      # If it's an ajax request, download the file and send it as the response
      # to the browser as json
      if request.xhr?
        file = db_session.file filePathName
        content_type 'application/json', :charset => 'utf-8'

        fileContents = file.download

        begin
          JSON.generate :filename => File.basename(filePathName),
                        :path     => File.dirname(filePathName),
                        :data     => fileContents
        rescue Encoding::UndefinedConversionError
          fileContents.force_encoding "UTF-8"
          retry
        end
      end
    end

    # Route for `POST/PUT /file`
    # ----------------------
    put '/file/*', do
        p session[:dropboxSession]
        # Initialize the dropbox session
        db_session = Dropbox::Session.deserialize(session[:dropboxSession])
        db_session.mode = :dropbox

        # Extract the path and filename
        dirname  = File.dirname(CGI.unescape(params[:splat][0]))
        filename = File.basename params[:splat][0]
        dirname = "" if dirname == "."

        # Extract the model data from the POST request, which will contain the
        # actual text file data
        model = JSON.parse request.body.read
        file_contents = model["data"]

        # Create the StringIO object and give it to the Dropbox class to upload
        strio = StringIO.new file_contents
        response = db_session.upload strio, dirname, :as => filename
        JSON.generate :response => response.result
    end

    # Uploads the provided file back into the Dropbox
    # %w(post put).each do |verb|
    #   send verb, '/file/*', do

    #     p session[:dropboxSession]
    #     # Initialize the dropbox session
    #     db_session = Dropbox::Session.deserialize(session[:dropboxSession])
    #     db_session.mode = :dropbox

    #     # Extract the path and filename
    #     dirname  = File.dirname(CGI.unescape(params[:splat][0]))
    #     filename = File.basename params[:splat][0]
    #     dirname = "" if dirname == "."

    #     # Extract the model data from the POST request, which will contain the
    #     # actual text file data
    #     model = JSON.parse request.body.read
    #     file_contents = model["data"]

    #     # Create the StringIO object and give it to the Dropbox class to upload
    #     strio = StringIO.new file_contents
    #     response = db_session.upload strio, dirname, :as => filename
    #     JSON.generate :response => response.result
    #   end
    # end

    # Route for `/css`
    # ----------------

    # Converts SASS to CSS
    get '/css/:stylesheet.css' do
      content_type 'text/css', :charset => 'utf-8'
      sass params[:stylesheet].to_sym
    end

  end
end

# Struct::to_hash
# ---------------

# Method to convert Struct objects to Ruby hash
class Struct
  def to_hash
    hash = {}
    self.members.each { |m| hash[m] = self[m] }
    hash
  end
end
