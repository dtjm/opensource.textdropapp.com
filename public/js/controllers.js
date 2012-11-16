(function() {
  window.AppController = Backbone.Controller.extend({
    document: null,
    loggedIn: false,
    documentView: null,
    rootView: null,
    fileBrowser: null,
    dropbox: null,
    routes: {
      "": "home",
      "new": "new",
      "edit/*path": "edit"
    },
    initialize: function(args) {
      this.documentView = new TextDocumentView;
      this.rootView = args != null ? args.rootView : void 0;
      $(this.rootView).append(this.documentView.el);
      this.dropbox = new Dropbox();
      return window.dropbox = this.dropbox;
    },
    home: function() {
      $(this.documentView.headerView.primaryButtons.newButton).button("disable");
      $(this.documentView.headerView.primaryButtons.browseButton).button("disable");
      $(this.documentView.headerView.primaryButtons.saveButton).button("disable");
      $(this.documentView.headerView.secondaryButtons.logoutButton).button("disable");
      return $(this.documentView.headerView.filenameLabel).html("<a href='/login'>Log in to TextDrop</a>");
    },
    "new": function() {
      var save, _ref;
      if (((_ref = this.document) != null ? _ref.state : void 0) === "DIRTY") {
        save = confirm("You forgot to save. I'm going to save for you.");
        if (save) {
          this.document.save({
            success: function(model, response) {
              this.document = new TextDocument();
              return this.documentView.setModel(this.document);
            }
          });
        }
      } else {
        this.document = new TextDocument();
        this.documentView.setModel(this.document);
        return this.document.trigger("change");
      }
    },
    edit: function(filePathName) {
      filePathName = decodeURI(filePathName);
      this.document = new TextDocument({
        id: "/" + filePathName
      });
      this.documentView.setModel(this.document);
      return this.document.fetch();
    }
  });
}).call(this);
