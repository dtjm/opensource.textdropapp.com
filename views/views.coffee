#window.AboutDialog = Backbone.View.extend

window.HeaderView = Backbone.View.extend

    # Properties
    tagName  : "div"
    className: "header-view"

    primaryButtons:   null
    filenameLabel:    null
    pathLabel:        null
    secondaryButtons: null

    initialize: () ->
      # Create the button bar views
      @primaryButtons   = new PrimaryButtonBar   model: @model
      @secondaryButtons = new SecondaryButtonBar model: @model
      @preferenceButtons = new PreferencesButtonBar model: @model

      @filenameLabel = @make "div", className: "filename-label"
      @pathLabel     = @make "div", className: "path-label"

      $(@el).append @primaryButtons.el,
          @filenameLabel,
          @secondaryButtons.el,
          @preferenceButtons.el

      # Bind change events
      if @model then @model.bind "change", @render

      _.bindAll this, "render"

    render: ->
        $(@filenameLabel).text @model.get 'filename'
        $(@pathLabel).text     @model.get 'path'

    setModel: (model) ->

        # Unbind events from previous model
        @model.unbind("change") if @model

        @model = model
        @model.bind "change", => @render()

        @primaryButtons.setModel @model
        @secondaryButtons.setModel @model
        @preferenceButtons.setModel @model

window.HomeView = Backbone.View.extend

    tagName: "div"
    className: "home-view"

    initialize: -> $(@el).html "<a href='/login'>Log in</a>"

window.PrimaryButtonBar = Backbone.View.extend

    tagName  : "div"
    className: "primary-button-bar"

    initialize: ->

        @newButton    = @make "a", {href: "#new"},  "New"
        @browseButton = @make "a", {href: ""}, "Open"
        @saveButton   = @make "a", {id: "save-button", href: ""}, "Save"

        $(@el).append @newButton, @browseButton, @saveButton

        $(@el).buttonset()

        view = this
        $(@newButton)
            .button
                icons:
                    primary: "ui-icon-document"
            .click (event) ->
                if jQuery(event.currentTarget).attr("disabled") == "true"
                    return false
                if view.model? && view.model.isNew()
                    view.model.set data: ""

        $(@browseButton)
            .button
                icons:
                    primary:"ui-icon-folder-open"
            .click (event) =>
                if jQuery(event.currentTarget).attr("disabled") == "true"
                    return false

                event.preventDefault()
                dialog = new OpenFileDialog()
                dialog.render()
                dialog.open()

        $(@saveButton)
            .button
                icons:
                    primary: "ui-icon-disk"
            .click (event) =>
                if jQuery(event.currentTarget).attr("disabled") == "true"
                    return false

                event.preventDefault()
                @model.save()

        _.bindAll this, "render"

    render: ->
        if not @model
            $(@el).buttonset "disable"
            return

        switch @model.state
            when "CLEAN"
                $(@saveButton).button "option", disabled: true, label: "Saved"
            when "SAVING"
                $(@saveButton).button "option", disabled: true, label: "Saving"
            else
                $(@saveButton).button "option", disabled: false, label: "Save"

    setModel: (model) ->
        @model.unbind "change" if @model
        @model = model
        @model.bind "change", @render


window.SecondaryButtonBar = Backbone.View.extend

    tagName:   "div"
    className: "secondary-button-bar"

    logoutButton: null

    initialize: ->
        @logoutButton = @make "a", {href: "/logout"}, "Log out"
        $(@el).append @logoutButton
        $(@logoutButton).button()

    setModel: (model) -> @model = model

PreferencesButtonBar = Backbone.View.extend

    tagName: "div"
    className: "preference-button-bar"

    autosaveInput: null

    initialize: () ->
        @autosaveInput = @make "input", {id: "pref-autosave", checked: "checked", type: "checkbox"}
        @autosaveLabel = @make "label", {for: "pref-autosave"}, "Autosave"
        $(@el).append @autosaveInput, @autosaveLabel

        view = this
        $(@autosaveInput).change (event, ui) ->
            if event.target.checked then view.model.startAutosave()
            else view.model.stopAutosave()

        $(@el).buttonset()
        $(@autosaveInput).button "disable"

    setModel: (model) ->
        @model = model

        if model?
            $(@autosaveInput).button "enable"

            if model.isNew() then $(@autosaveInput).removeAttr("checked").button("refresh")

            if @autosaveInput.checked then model.startAutosave()
            else model.stopAutosave()
        else
            $(@autosaveInput).button "disable"

# SaveDialog
# ----------

window.SaveDialog = Backbone.View.extend

    tagName: "div"
    className: "save-dialog"

    fnSuccess: null
    dialog   : null
    browser:   null
    filenameLabel: null
    filenameField: null

    close: -> $(@el).dialog("close").remove()

    initialize: (args) ->

        @fnSuccess = args?.success

        @browser = new DropboxBrowser
            model: window.dropbox

        @dirLabel = @make "label", {"for": "directory"}, "Folder: "
        @dirField = @make "div", id: "directory"
        $(@dirField).append @browser.statusBar

        @filenameLabel = @make "label", {"for": "filename"}, "Filename: "
        @filenameField = @make "input", type: "text", id: "filename", value: "Untitled"

        clearDiv = @make "div", style: "clear: both"
        $(@el).dialog
            draggable: true
            modal: true
            position: ["center", 100]
            resizable: true
            title: "Save"
            buttons:
                "Save": =>
                    args.select window.dropbox.get("cwd"), @filenameField.value
                    @close()

        $(@el).append @filenameLabel, @filenameField,
            @dirLabel, @dirField,
            clearDiv
            @browser.el

        _.bindAll this, "render", "close", "open"

        $(@filenameField).focus()

    open: -> $(@el).dialog "open"

    render: -> @browser.render()


# TextDocumentView
# ----------------

# View for rendering a text document
window.TextDocumentView = Backbone.View.extend

    tagName: "div"
    className: "text-document-view"

    # Sub-elements
    textarea: null
    shadowElement: null

    # Sub-views
    headerView: null

    # Other properties
    cursorPosition: 0

    initialize: () ->

        # Whenever the window is resized, resize the textarea to fit
        $(window).bind "resize", => @_fitTextArea()

        # Make the text area
        @textarea = @make "textarea", name: "data"

        # Bind events to textarea
        $(@textarea)
            .bind("paste", (event) => _.defer(() => @_fitTextArea()))
            .keyup((event) => @handleKeyDown event)
            .keydown((event) -> Util.checkTab event)
            .click (event) => @_updateCursorPosition()

        # Make the shadow area
        @shadowElement = @make "pre", id: "textarea-shadow"

        # Initialize header view
        @headerView = new HeaderView(model: @model)

        # Append sub-elements
        $(@el).append @textarea, @shadowElement
        $("body").prepend @headerView.el

        # Catch the Cmd-S and save
        $(window).keydown (event) =>
            if event.metaKey && event.which == 83
                event.preventDefault()
                @model.save()

        _.bindAll this, "render"

    # When any key is pressed, sync the changes back to the model and refit the
    # textarea
    handleKeyDown: (event) ->
        @_syncModelToMarkup()
        @_fitTextArea()
        @_updateCursorPosition()

    # Render the textDocument
    render: () ->

        title = "#{@model.get('filename')} - TextDrop"

        switch @model.state
            when "FETCHING"
                @_renderLoadingPlaceholder()
                $(@textarea).addClass("loading").attr "disabled", true
            when "DIRTY"
                document.title = "*#{title}"
                $(@textarea).val(@model.get "data")
            when "REQUESTING_FILENAME"
                if $(".save-dialog").is ":visible" then return
                saveDialog = new SaveDialog select: (directory, filename) =>

                    if directory == "/" then directory = ""

                    if filename.indexOf(".") == -1
                        filename += ".txt"

                    @model.set filename: filename, path: directory
                    @model.id = "#{directory}/#{filename}"
                    @model.save success:
                        setTimeout (=> window.location.hash = "edit#{@model.id}"), 1000

                saveDialog.render()
                saveDialog.open()
            else
                $(@textarea).removeAttr("disabled").removeClass("loading")
                $(@textarea).val(@model.get "data")
                if _(@textarea.setSelectionRange).isFunction()
                    @textarea.setSelectionRange @cursorPosition, @cursorPosition
                @_fitTextArea()
                @headerView.render()
                document.title = title

    setModel: (model) ->

        # Unbind events from previous model
        @model.unbind "change" if @model

        @model = model
        @model.bind "change", => @render()

        @headerView.setModel @model

    # Automatically resize the text area by creating a "shadow" `<div>` with the
    # same contents of the `<textarea>`, then copy the height to the
    # `<textarea>`
    _fitTextArea: () ->
        contents = $(@textarea).val() #.replace /\n/g, "<br>"
        $(@shadowElement).text contents
        $(@textarea).height($(@shadowElement).height() + 30)
        # $(@textarea).css("padding-top", $(@headerView.el).height() + "px")

    # Copy the `<textarea>` contents to the model
    _syncModelToMarkup: () ->
        @model.set data: $(@textarea).val()

    # When the file is still loading from the server...
    _renderLoadingPlaceholder: () ->

        if $(@textarea).val().indexOf("Loading...") != 0
            $(@textarea).val "Loading..."
            window.scrollTo 0,0
            setTimeout @render, 300
        else
            $(@textarea).val($(@textarea).val() + ".")
            if @model.state == "FETCHING"
                setTimeout @render, 300

    _updateCursorPosition: () ->
        @cursorPosition = @textarea.selectionStart
