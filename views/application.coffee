# TextDocument
# ------------

# Model for representing a document
window.TextDocument = Backbone.Model.extend

    defaults:
        filename: "Untitled"
        path:     "/"

    autosaveTimerId: null

    # Methods
    # -------
    fetch: (args) ->

        @state = "FETCHING"
        @trigger "change"

        success = (model, response) =>
            args.success(model, response) if _.isFunction args?.success
            model.state = "CLEAN"
            model.trigger "change"

        error = (model, response) =>
            args.error(model, response) if _.isFunction args?.error
            model.state = "FETCH_ERROR"

        # Call parent fetch method
        Backbone.Model.prototype.fetch.call(this,
            success: success,
            error:   error)

    initialize: (args) ->
        # If the model changes, then call the didChange callback
        @bind "change:data", (event) => @state = "DIRTY"

        # Parse the filePathName
        if @id? then @set
            filename: Util.basename(@id)
            path:     Util.dirname(@id)

    save: (attributes, options) ->

        # Get a filename to save if its a new file
        if @isNew()
            @state = "REQUESTING_FILENAME"
            @trigger "change"
            return

        @state = "SAVING"
        @trigger "change"

        success = (model, response) =>
            model.state = "CLEAN"
            model.trigger "change"

            # Clear the dropbox dir cache
            window.dropbox._cache = {}

            options.success(model, response) if _.isFunction options?.success

        error = (model, response) =>
            options.error(model, response) if _.isFunction options?.error
            log "SAVE_ERROR", model
            model.state = "SAVE_ERROR"

        Backbone.Model.prototype.save.call this, attributes,
            success: success
            error:   error

    startAutosave: () ->
        me = this
        autosave = () ->
            if me.isNew() || (me.state? && me.state == "DIRTY")
                me.save {},
                    silent: true
                    success: () ->
                        me.autosaveTimerId = setTimeout autosave, 10000
                    error: () ->
                        me.autosaveTimerId = setTimeout autosave, 10000
            else
                me.autosaveTimerId = setTimeout autosave, 10000
        autosave()

    stopAutosave: () ->
        if @autosaveTimerId
            clearTimeout @autosaveTimerId
            @autosaveTimerId = null

    # Generate the resource URL
    url: -> if @id then return "/file#{@id}"

# Dropbox model
# -------------

# Properties:
#
# - cwd  - current working directory
# - tree - in-memory directory tree structure
window.Dropbox = Backbone.Model.extend

    _cache: {}

    cacheDirList: (dirList) -> @_cache[@get "cwd"] = dirList

    # Change directory
    cd: (path) ->
        if path.indexOf("/browse") == 0 then path = path.substr 7
        @set cwd: path

    # Build the URL used to fetch the directory contents from the backend
    getBrowseURL: -> "/browse#{@get 'cwd'}"

    # Get the cached directory listing
    getCachedDirList: -> return @_cache[@get "cwd"]

    # Initialize with the `cwd` set to the Dropbox root
    initialize: -> @set cwd: "/"

    # Fetch the contents of the current directory and run the callback when it's
    # ready
    listCurrentDirectory: (callback) ->
        # Try to get the cached directory listing
        dirList = @getCachedDirList()

        # If we found the cached data, use it
        if dirList? then callback dirList

        # Otherwise, go fetch it
        else
            $.getJSON @getBrowseURL(),
                (data) =>
                    if data.status == "NOTLOGGEDIN" then window.location = "/"
                    dirList = @parseServerDirList data
                    @cacheDirList dirList
                    callback dirList

    # Get the file list out of the server response
    parseServerDirList: (data) -> data.files

# BrowserView
# -----------

# A Finder-style view for browsing the Dropbox directory.
#
# The BrowserView can be used as a component of the OpenFileDialog
window.DropboxBrowser = Backbone.View.extend

    statusBar: null

    initialize: (args) ->
        # Render the view when the model changes
        @model.bind "change", => @render()

        # Build the elements
        @el = $ @make "ul", class: "dropbox-browser"
        @statusBar = $ @make "ul"
        @statusBar.after @make "div", class: "clear"

        @dirOnly = args?.dirOnly

    isEditable: (file) ->
        lowerCaseFilePath = file.path.toLowerCase()

        (file.mime_type? and Util.startsWith "text/", file.mime_type) or
        lowerCaseFilePath.indexOf(".taskpaper") != -1 or
        lowerCaseFilePath.indexOf(".xml") != -1 or
        lowerCaseFilePath.indexOf(".vba") != -1 or
        lowerCaseFilePath.indexOf(".xsl") != -1 or
        lowerCaseFilePath.indexOf(".bat") != -1 or
        lowerCaseFilePath.indexOf(".text") != -1

    render: (success) ->
        # Set the *Loading* text while the directory loads from the server
        @el.text "Loading..."

        # Clear the status bar
        @statusBar.empty()

        # Fetch the directory, render it when it's ready
        @model.listCurrentDirectory (dirList) => @renderDirList dirList, success

        # Also render the status bar
        @renderStatusBar success

    # Render the directory entries
    renderDirList: (dirList, success) ->

        # Clear the DOM node
        @el.empty()

        for file in dirList
            if @dirOnly and not file.is_dir then continue

            filename = Util.basename file.path
            filePath = encodeURI file.path
            if filename.substr(0,1) == "."
                continue

            $li = $ "<li/>"

            #if !file.is_dir && file.mime_type? &&
            #file.mime_type == 'text/plain'
                #$li.addClass "disabled"

            $li.append "<span class='sprite s_#{file.icon}'/>"

            # Make text files editable
            if @isEditable file
                $a = $ @make "a", {href: "#edit#{filePath}"}, filename
                $a.click (event) => @trigger "select"
                $li.append $a

            # Make directories browsable
            else if file.is_dir
                $a = $ @make "a",
                    {class: "browse", href: "/browse#{filePath}"},
                    filename

                $a.click (event) => @model.cd event.target.pathname; return false

                $li.append $a

            # Everything else
            else
                $li.append @make "span", null, filename

            # Put the item in the list
            @el.append $li

        if success? then success()


    # Render the status bar as a list of directories:
    #
    #     Dropbox > Level 1 > Bar > Current Dir
    renderStatusBar: (success) ->
        path = @model.get "cwd"
        parts = null;

        if path == '' or path == '/' then parts = []
        else
            # Split the path by forward slashes
            parts = path.split /\//

            # Create the `<a>` element
            $a = $ @make "a", {class: "browse", href: '/browse/'}, "Dropbox"

            # Bind the click event to make the model change directories, which
            # will trigger a render of the directory listing
            $a.click (event) =>
                @model.cd event.target.pathname
                return false

            # Create the `<li>` element and append it to the *statusBar*
            $li = $ @make "li"
            $li.append $a
            @statusBar.append $li

            # The path from the root up to the directory in the current
            # iteration of the loop. Each iteration will add one more part of
            # the entire path, e.g.,
            #
            # 1. /
            # 2. /level1
            # 3. /level1/bar
            # 4. /level1/bar/current_dir
            partialDir = ""

            for i in [0..parts.length-1]
                parts[i] = decodeURI parts[i]
                if parts[i] == "" then continue
                else if i == (parts.length - 1)
                    @statusBar.append "<li>&nbsp;&gt; #{parts[i]}</li>"
                else
                    partialDir += "/#{parts[i]}"
                    $li = $ @make "li", {}, "&nbsp;&gt; "
                    $a = $ @make "a", {href: "/browse#{partialDir}"}, parts[i]

                    $a.click (event) =>
                        @model.cd event.target.pathname
                        return false

                    $li.append($a).appendTo @statusBar

            if success? then success()

    # Accessor
    getStatusBar: -> return @statusBar


# OpenFileDialog
# --------------

# Dialog container that uses the DropboxBrowser as a subview. May be extended in
# the future to allow other subviews such as an MRU browser
window.OpenFileDialog = Backbone.View.extend

    currentView: null
    fileBrowser: null
    statusBar:   null

    close: -> @el.dialog "close"

    # Create the div and the dialog
    initialize: ->
        @el = $("<div/>").dialog
            autoOpen: false
            draggable: true
            modal: true
            title: "Open a file"

        @initStatusBar()

        @setCurrentView "DropboxBrowser"

        # Append the currentView to the dialog
        @el.append @currentView

    initStatusBar: ->
        @statusBar = $ @make "div", class: 'ui-dialog-buttonpane'
        @statusBar.insertAfter @el

    getFileBrowser: ->
        if @fileBrowser? then return @fileBrowser
        else return @fileBrowser = new FileBrowser()

    open: ->
        @el.dialog "open"
        return this

    render: ->
        @currentView.render () =>
            @el.css "max-height", ($(window).height() - 100)
            @el.dialog "option", "position", ["center", "center"]

        return this

    # When setting the current view, get the main element as well as the
    # statusBar element
    setCurrentView: (view) ->
        switch view
            when "DropboxBrowser"
                @currentView = new DropboxBrowser model: window.dropbox

        @currentView.bind "select", (event) => @close()

        @el.empty().append @currentView.el
        @statusBar.empty().append @currentView.statusBar, (@make "div", class: "clear")

    # Set the mode; currently only the *filebrowser* mode exists, but in the
    # future I'll add the *MRU* mode
    setMode: (mode) ->
        switch mode
            when "filebrowser"
                @currentView = @fileBrowser

        @statusBar = @currentView.getStatusBar()
