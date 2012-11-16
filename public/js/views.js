(function() {
  var PreferencesButtonBar;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  window.HeaderView = Backbone.View.extend({
    tagName: "div",
    className: "header-view",
    primaryButtons: null,
    filenameLabel: null,
    pathLabel: null,
    secondaryButtons: null,
    initialize: function() {
      this.primaryButtons = new PrimaryButtonBar({
        model: this.model
      });
      this.secondaryButtons = new SecondaryButtonBar({
        model: this.model
      });
      this.preferenceButtons = new PreferencesButtonBar({
        model: this.model
      });
      this.filenameLabel = this.make("div", {
        className: "filename-label"
      });
      this.pathLabel = this.make("div", {
        className: "path-label"
      });
      $(this.el).append(this.primaryButtons.el, this.filenameLabel, this.secondaryButtons.el, this.preferenceButtons.el);
      if (this.model) {
        this.model.bind("change", this.render);
      }
      return _.bindAll(this, "render");
    },
    render: function() {
      $(this.filenameLabel).text(this.model.get('filename'));
      return $(this.pathLabel).text(this.model.get('path'));
    },
    setModel: function(model) {
      if (this.model) {
        this.model.unbind("change");
      }
      this.model = model;
      this.model.bind("change", __bind(function() {
        return this.render();
      }, this));
      this.primaryButtons.setModel(this.model);
      this.secondaryButtons.setModel(this.model);
      return this.preferenceButtons.setModel(this.model);
    }
  });
  window.HomeView = Backbone.View.extend({
    tagName: "div",
    className: "home-view",
    initialize: function() {
      return $(this.el).html("<a href='/login'>Log in</a>");
    }
  });
  window.PrimaryButtonBar = Backbone.View.extend({
    tagName: "div",
    className: "primary-button-bar",
    initialize: function() {
      var view;
      this.newButton = this.make("a", {
        href: "#new"
      }, "New");
      this.browseButton = this.make("a", {
        href: ""
      }, "Open");
      this.saveButton = this.make("a", {
        id: "save-button",
        href: ""
      }, "Save");
      $(this.el).append(this.newButton, this.browseButton, this.saveButton);
      $(this.el).buttonset();
      view = this;
      $(this.newButton).button({
        icons: {
          primary: "ui-icon-document"
        }
      }).click(function(event) {
        if (jQuery(event.currentTarget).attr("disabled") === "true") {
          return false;
        }
        if ((view.model != null) && view.model.isNew()) {
          return view.model.set({
            data: ""
          });
        }
      });
      $(this.browseButton).button({
        icons: {
          primary: "ui-icon-folder-open"
        }
      }).click(__bind(function(event) {
        var dialog;
        if (jQuery(event.currentTarget).attr("disabled") === "true") {
          return false;
        }
        event.preventDefault();
        dialog = new OpenFileDialog();
        dialog.render();
        return dialog.open();
      }, this));
      $(this.saveButton).button({
        icons: {
          primary: "ui-icon-disk"
        }
      }).click(__bind(function(event) {
        if (jQuery(event.currentTarget).attr("disabled") === "true") {
          return false;
        }
        event.preventDefault();
        return this.model.save();
      }, this));
      return _.bindAll(this, "render");
    },
    render: function() {
      if (!this.model) {
        $(this.el).buttonset("disable");
        return;
      }
      switch (this.model.state) {
        case "CLEAN":
          return $(this.saveButton).button("option", {
            disabled: true,
            label: "Saved"
          });
        case "SAVING":
          return $(this.saveButton).button("option", {
            disabled: true,
            label: "Saving"
          });
        default:
          return $(this.saveButton).button("option", {
            disabled: false,
            label: "Save"
          });
      }
    },
    setModel: function(model) {
      if (this.model) {
        this.model.unbind("change");
      }
      this.model = model;
      return this.model.bind("change", this.render);
    }
  });
  window.SecondaryButtonBar = Backbone.View.extend({
    tagName: "div",
    className: "secondary-button-bar",
    logoutButton: null,
    initialize: function() {
      this.logoutButton = this.make("a", {
        href: "/logout"
      }, "Log out");
      $(this.el).append(this.logoutButton);
      return $(this.logoutButton).button();
    },
    setModel: function(model) {
      return this.model = model;
    }
  });
  PreferencesButtonBar = Backbone.View.extend({
    tagName: "div",
    className: "preference-button-bar",
    autosaveInput: null,
    initialize: function() {
      var view;
      this.autosaveInput = this.make("input", {
        id: "pref-autosave",
        checked: "checked",
        type: "checkbox"
      });
      this.autosaveLabel = this.make("label", {
        "for": "pref-autosave"
      }, "Autosave");
      $(this.el).append(this.autosaveInput, this.autosaveLabel);
      view = this;
      $(this.autosaveInput).change(function(event, ui) {
        if (event.target.checked) {
          return view.model.startAutosave();
        } else {
          return view.model.stopAutosave();
        }
      });
      $(this.el).buttonset();
      return $(this.autosaveInput).button("disable");
    },
    setModel: function(model) {
      this.model = model;
      if (model != null) {
        $(this.autosaveInput).button("enable");
        if (model.isNew()) {
          $(this.autosaveInput).removeAttr("checked").button("refresh");
        }
        if (this.autosaveInput.checked) {
          return model.startAutosave();
        } else {
          return model.stopAutosave();
        }
      } else {
        return $(this.autosaveInput).button("disable");
      }
    }
  });
  window.SaveDialog = Backbone.View.extend({
    tagName: "div",
    className: "save-dialog",
    fnSuccess: null,
    dialog: null,
    browser: null,
    filenameLabel: null,
    filenameField: null,
    close: function() {
      return $(this.el).dialog("close").remove();
    },
    initialize: function(args) {
      var clearDiv;
      this.fnSuccess = args != null ? args.success : void 0;
      this.browser = new DropboxBrowser({
        model: window.dropbox
      });
      this.dirLabel = this.make("label", {
        "for": "directory"
      }, "Folder: ");
      this.dirField = this.make("div", {
        id: "directory"
      });
      $(this.dirField).append(this.browser.statusBar);
      this.filenameLabel = this.make("label", {
        "for": "filename"
      }, "Filename: ");
      this.filenameField = this.make("input", {
        type: "text",
        id: "filename",
        value: "Untitled"
      });
      clearDiv = this.make("div", {
        style: "clear: both"
      });
      $(this.el).dialog({
        draggable: true,
        modal: true,
        position: ["center", 100],
        resizable: true,
        title: "Save",
        buttons: {
          "Save": __bind(function() {
            args.select(window.dropbox.get("cwd"), this.filenameField.value);
            return this.close();
          }, this)
        }
      });
      $(this.el).append(this.filenameLabel, this.filenameField, this.dirLabel, this.dirField, clearDiv, this.browser.el);
      _.bindAll(this, "render", "close", "open");
      return $(this.filenameField).focus();
    },
    open: function() {
      return $(this.el).dialog("open");
    },
    render: function() {
      return this.browser.render();
    }
  });
  window.TextDocumentView = Backbone.View.extend({
    tagName: "div",
    className: "text-document-view",
    textarea: null,
    shadowElement: null,
    headerView: null,
    cursorPosition: 0,
    initialize: function() {
      $(window).bind("resize", __bind(function() {
        return this._fitTextArea();
      }, this));
      this.textarea = this.make("textarea", {
        name: "data"
      });
      $(this.textarea).bind("paste", __bind(function(event) {
        return _.defer(__bind(function() {
          return this._fitTextArea();
        }, this));
      }, this)).keyup(__bind(function(event) {
        return this.handleKeyDown(event);
      }, this)).keydown(function(event) {
        return Util.checkTab(event);
      }).click(__bind(function(event) {
        return this._updateCursorPosition();
      }, this));
      this.shadowElement = this.make("pre", {
        id: "textarea-shadow"
      });
      this.headerView = new HeaderView({
        model: this.model
      });
      $(this.el).append(this.textarea, this.shadowElement);
      $("body").prepend(this.headerView.el);
      $(window).keydown(__bind(function(event) {
        if (event.metaKey && event.which === 83) {
          event.preventDefault();
          return this.model.save();
        }
      }, this));
      return _.bindAll(this, "render");
    },
    handleKeyDown: function(event) {
      this._syncModelToMarkup();
      this._fitTextArea();
      return this._updateCursorPosition();
    },
    render: function() {
      var saveDialog, title;
      title = "" + (this.model.get('filename')) + " - TextDrop";
      switch (this.model.state) {
        case "FETCHING":
          this._renderLoadingPlaceholder();
          return $(this.textarea).addClass("loading").attr("disabled", true);
        case "DIRTY":
          document.title = "*" + title;
          return $(this.textarea).val(this.model.get("data"));
        case "REQUESTING_FILENAME":
          if ($(".save-dialog").is(":visible")) {
            return;
          }
          saveDialog = new SaveDialog({
            select: __bind(function(directory, filename) {
              if (directory === "/") {
                directory = "";
              }
              if (filename.indexOf(".") === -1) {
                filename += ".txt";
              }
              this.model.set({
                filename: filename,
                path: directory
              });
              this.model.id = "" + directory + "/" + filename;
              return this.model.save({
                success: setTimeout((__bind(function() {
                  return window.location.hash = "edit" + this.model.id;
                }, this)), 1000)
              });
            }, this)
          });
          saveDialog.render();
          return saveDialog.open();
        default:
          $(this.textarea).removeAttr("disabled").removeClass("loading");
          $(this.textarea).val(this.model.get("data"));
          if (_(this.textarea.setSelectionRange).isFunction()) {
            this.textarea.setSelectionRange(this.cursorPosition, this.cursorPosition);
          }
          this._fitTextArea();
          this.headerView.render();
          return document.title = title;
      }
    },
    setModel: function(model) {
      if (this.model) {
        this.model.unbind("change");
      }
      this.model = model;
      this.model.bind("change", __bind(function() {
        return this.render();
      }, this));
      return this.headerView.setModel(this.model);
    },
    _fitTextArea: function() {
      var contents;
      contents = $(this.textarea).val();
      $(this.shadowElement).text(contents);
      return $(this.textarea).height($(this.shadowElement).height() + 30);
    },
    _syncModelToMarkup: function() {
      return this.model.set({
        data: $(this.textarea).val()
      });
    },
    _renderLoadingPlaceholder: function() {
      if ($(this.textarea).val().indexOf("Loading...") !== 0) {
        $(this.textarea).val("Loading...");
        window.scrollTo(0, 0);
        return setTimeout(this.render, 300);
      } else {
        $(this.textarea).val($(this.textarea).val() + ".");
        if (this.model.state === "FETCHING") {
          return setTimeout(this.render, 300);
        }
      }
    },
    _updateCursorPosition: function() {
      return this.cursorPosition = this.textarea.selectionStart;
    }
  });
}).call(this);
