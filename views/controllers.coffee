window.AppController = Backbone.Controller.extend

    document: null
    loggedIn: false

    documentView: null
    rootView:     null
    fileBrowser:  null
    dropbox: null

    routes:
        "":    "home"
        "new": "new"
        "edit/*path"  : "edit"

    initialize: (args) ->
        @documentView = new TextDocumentView

        @rootView = args?.rootView

        $(@rootView).append @documentView.el

        @dropbox = new Dropbox()

        window.dropbox = @dropbox

    home: ->
        # Disable buttons
        $(@documentView.headerView.primaryButtons.newButton).button "disable"
        $(@documentView.headerView.primaryButtons.browseButton).button "disable"
        $(@documentView.headerView.primaryButtons.saveButton).button "disable"
        $(@documentView.headerView.secondaryButtons.logoutButton).button "disable"

        $(@documentView.headerView.filenameLabel).html(
            "<a href='/login'>Log in to TextDrop</a>")

    new: () ->

        if @document?.state == "DIRTY"
            save = confirm "You forgot to save. I'm going to save for you."

            if save
                @document.save success: (model, response) ->
                    @document = new TextDocument()
                    @documentView.setModel @document
                return

        else
            @document = new TextDocument()
            @documentView.setModel @document
            @document.trigger "change"

    edit: (filePathName) ->

        filePathName = decodeURI filePathName

        @document = new TextDocument id: "/#{filePathName}"

        @documentView.setModel @document

        @document.fetch()
