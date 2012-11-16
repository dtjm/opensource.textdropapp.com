(function() {
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  window.TextDocument = Backbone.Model.extend({
    defaults: {
      filename: "Untitled",
      path: "/"
    },
    autosaveTimerId: null,
    fetch: function(args) {
      var error, success;
      this.state = "FETCHING";
      this.trigger("change");
      success = __bind(function(model, response) {
        if (_.isFunction(args != null ? args.success : void 0)) {
          args.success(model, response);
        }
        model.state = "CLEAN";
        return model.trigger("change");
      }, this);
      error = __bind(function(model, response) {
        if (_.isFunction(args != null ? args.error : void 0)) {
          args.error(model, response);
        }
        return model.state = "FETCH_ERROR";
      }, this);
      return Backbone.Model.prototype.fetch.call(this, {
        success: success,
        error: error
      });
    },
    initialize: function(args) {
      this.bind("change:data", __bind(function(event) {
        return this.state = "DIRTY";
      }, this));
      if (this.id != null) {
        return this.set({
          filename: Util.basename(this.id),
          path: Util.dirname(this.id)
        });
      }
    },
    save: function(attributes, options) {
      var error, success;
      if (this.isNew()) {
        this.state = "REQUESTING_FILENAME";
        this.trigger("change");
        return;
      }
      this.state = "SAVING";
      this.trigger("change");
      success = __bind(function(model, response) {
        model.state = "CLEAN";
        model.trigger("change");
        window.dropbox._cache = {};
        if (_.isFunction(options != null ? options.success : void 0)) {
          return options.success(model, response);
        }
      }, this);
      error = __bind(function(model, response) {
        if (_.isFunction(options != null ? options.error : void 0)) {
          options.error(model, response);
        }
        log("SAVE_ERROR", model);
        return model.state = "SAVE_ERROR";
      }, this);
      return Backbone.Model.prototype.save.call(this, attributes, {
        success: success,
        error: error
      });
    },
    startAutosave: function() {
      var autosave, me;
      me = this;
      autosave = function() {
        if (me.isNew() || ((me.state != null) && me.state === "DIRTY")) {
          return me.save({}, {
            silent: true,
            success: function() {
              return me.autosaveTimerId = setTimeout(autosave, 10000);
            },
            error: function() {
              return me.autosaveTimerId = setTimeout(autosave, 10000);
            }
          });
        } else {
          return me.autosaveTimerId = setTimeout(autosave, 10000);
        }
      };
      return autosave();
    },
    stopAutosave: function() {
      if (this.autosaveTimerId) {
        clearTimeout(this.autosaveTimerId);
        return this.autosaveTimerId = null;
      }
    },
    url: function() {
      if (this.id) {
        return "/file" + this.id;
      }
    }
  });
  window.Dropbox = Backbone.Model.extend({
    _cache: {},
    cacheDirList: function(dirList) {
      return this._cache[this.get("cwd")] = dirList;
    },
    cd: function(path) {
      if (path.indexOf("/browse") === 0) {
        path = path.substr(7);
      }
      return this.set({
        cwd: path
      });
    },
    getBrowseURL: function() {
      return "/browse" + (this.get('cwd'));
    },
    getCachedDirList: function() {
      return this._cache[this.get("cwd")];
    },
    initialize: function() {
      return this.set({
        cwd: "/"
      });
    },
    listCurrentDirectory: function(callback) {
      var dirList;
      dirList = this.getCachedDirList();
      if (dirList != null) {
        return callback(dirList);
      } else {
        return $.getJSON(this.getBrowseURL(), __bind(function(data) {
          if (data.status === "NOTLOGGEDIN") {
            window.location = "/";
          }
          dirList = this.parseServerDirList(data);
          this.cacheDirList(dirList);
          return callback(dirList);
        }, this));
      }
    },
    parseServerDirList: function(data) {
      return data.files;
    }
  });
  window.DropboxBrowser = Backbone.View.extend({
    statusBar: null,
    initialize: function(args) {
      this.model.bind("change", __bind(function() {
        return this.render();
      }, this));
      this.el = $(this.make("ul", {
        "class": "dropbox-browser"
      }));
      this.statusBar = $(this.make("ul"));
      this.statusBar.after(this.make("div", {
        "class": "clear"
      }));
      return this.dirOnly = args != null ? args.dirOnly : void 0;
    },
    isEditable: function(file) {
      var lowerCaseFilePath;
      lowerCaseFilePath = file.path.toLowerCase();
      return ((file.mime_type != null) && Util.startsWith("text/", file.mime_type)) || lowerCaseFilePath.indexOf(".taskpaper") !== -1 || lowerCaseFilePath.indexOf(".xml") !== -1 || lowerCaseFilePath.indexOf(".vba") !== -1 || lowerCaseFilePath.indexOf(".xsl") !== -1 || lowerCaseFilePath.indexOf(".bat") !== -1 || lowerCaseFilePath.indexOf(".text") !== -1;
    },
    render: function(success) {
      this.el.text("Loading...");
      this.statusBar.empty();
      this.model.listCurrentDirectory(__bind(function(dirList) {
        return this.renderDirList(dirList, success);
      }, this));
      return this.renderStatusBar(success);
    },
    renderDirList: function(dirList, success) {
      var $a, $li, file, filePath, filename, _i, _len;
      this.el.empty();
      for (_i = 0, _len = dirList.length; _i < _len; _i++) {
        file = dirList[_i];
        if (this.dirOnly && !file.is_dir) {
          continue;
        }
        filename = Util.basename(file.path);
        filePath = encodeURI(file.path);
        if (filename.substr(0, 1) === ".") {
          continue;
        }
        $li = $("<li/>");
        $li.append("<span class='sprite s_" + file.icon + "'/>");
        if (this.isEditable(file)) {
          $a = $(this.make("a", {
            href: "#edit" + filePath
          }, filename));
          $a.click(__bind(function(event) {
            return this.trigger("select");
          }, this));
          $li.append($a);
        } else if (file.is_dir) {
          $a = $(this.make("a", {
            "class": "browse",
            href: "/browse" + filePath
          }, filename));
          $a.click(__bind(function(event) {
            this.model.cd(event.target.pathname);
            return false;
          }, this));
          $li.append($a);
        } else {
          $li.append(this.make("span", null, filename));
        }
        this.el.append($li);
      }
      if (success != null) {
        return success();
      }
    },
    renderStatusBar: function(success) {
      var $a, $li, i, partialDir, parts, path, _ref;
      path = this.model.get("cwd");
      parts = null;
      if (path === '' || path === '/') {
        return parts = [];
      } else {
        parts = path.split(/\//);
        $a = $(this.make("a", {
          "class": "browse",
          href: '/browse/'
        }, "Dropbox"));
        $a.click(__bind(function(event) {
          this.model.cd(event.target.pathname);
          return false;
        }, this));
        $li = $(this.make("li"));
        $li.append($a);
        this.statusBar.append($li);
        partialDir = "";
        for (i = 0, _ref = parts.length - 1; 0 <= _ref ? i <= _ref : i >= _ref; 0 <= _ref ? i++ : i--) {
          parts[i] = decodeURI(parts[i]);
          if (parts[i] === "") {
            continue;
          } else if (i === (parts.length - 1)) {
            this.statusBar.append("<li>&nbsp;&gt; " + parts[i] + "</li>");
          } else {
            partialDir += "/" + parts[i];
            $li = $(this.make("li", {}, "&nbsp;&gt; "));
            $a = $(this.make("a", {
              href: "/browse" + partialDir
            }, parts[i]));
            $a.click(__bind(function(event) {
              this.model.cd(event.target.pathname);
              return false;
            }, this));
            $li.append($a).appendTo(this.statusBar);
          }
        }
        if (success != null) {
          return success();
        }
      }
    },
    getStatusBar: function() {
      return this.statusBar;
    }
  });
  window.OpenFileDialog = Backbone.View.extend({
    currentView: null,
    fileBrowser: null,
    statusBar: null,
    close: function() {
      return this.el.dialog("close");
    },
    initialize: function() {
      this.el = $("<div/>").dialog({
        autoOpen: false,
        draggable: true,
        modal: true,
        title: "Open a file"
      });
      this.initStatusBar();
      this.setCurrentView("DropboxBrowser");
      return this.el.append(this.currentView);
    },
    initStatusBar: function() {
      this.statusBar = $(this.make("div", {
        "class": 'ui-dialog-buttonpane'
      }));
      return this.statusBar.insertAfter(this.el);
    },
    getFileBrowser: function() {
      if (this.fileBrowser != null) {
        return this.fileBrowser;
      } else {
        return this.fileBrowser = new FileBrowser();
      }
    },
    open: function() {
      this.el.dialog("open");
      return this;
    },
    render: function() {
      this.currentView.render(__bind(function() {
        this.el.css("max-height", $(window).height() - 100);
        return this.el.dialog("option", "position", ["center", "center"]);
      }, this));
      return this;
    },
    setCurrentView: function(view) {
      switch (view) {
        case "DropboxBrowser":
          this.currentView = new DropboxBrowser({
            model: window.dropbox
          });
      }
      this.currentView.bind("select", __bind(function(event) {
        return this.close();
      }, this));
      this.el.empty().append(this.currentView.el);
      return this.statusBar.empty().append(this.currentView.statusBar, this.make("div", {
        "class": "clear"
      }));
    },
    setMode: function(mode) {
      switch (mode) {
        case "filebrowser":
          this.currentView = this.fileBrowser;
      }
      return this.statusBar = this.currentView.getStatusBar();
    }
  });
}).call(this);
