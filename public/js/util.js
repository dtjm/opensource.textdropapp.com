(function() {
  if (window.Util == null) {
    window.Util = {
      defaults: {
        tab: "    "
      },
      basename: function(path, suffix) {
        var b;
        b = path.replace(/^.*[\/\\]/g, '');
        if (typeof suffix === 'string' && b.substr(b.length - suffix.length) === suffix) {
          b = b.substr(0, b.length - suffix.length);
        }
        return b;
      },
      checkTab: function(evt) {
        var post, pre, se, sel, ss, t, tab;
        if (evt.metaKey) {
          return;
        }
        tab = this.defaults.tab;
        t = evt.target;
        ss = t.selectionStart;
        se = t.selectionEnd;
        if (evt.keyCode === 9) {
          evt.preventDefault();
          if (ss !== se && t.value.slice(ss, se).indexOf("\n") !== -1) {
            pre = t.value.slice(0, ss);
            sel = t.value.slice(ss, se).replace(/\n/g, "\n" + tab);
            post = t.value.slice(se, t.value.length);
            t.value = pre.concat(tab).concat(sel).concat(post);
            t.selectionStart = ss + tab.length;
            return t.selectionEnd = se + tab.length;
          } else {
            t.value = t.value.slice(0, ss).concat(tab).concat(t.value.slice(ss, t.value.length));
            if (ss === se) {
              return t.selectionStart = t.selectionEnd = ss + tab.length;
            } else {
              t.selectionStart = ss + tab.length;
              return t.selectionEnd = se + tab.length;
            }
          }
        } else if (evt.keyCode === 8 && t.value.slice(ss - 4, ss) === tab) {
          evt.preventDefault();
          t.value = t.value.slice(0, ss - 4).concat(t.value.slice(ss, t.value.length));
          return t.selectionStart = t.selectionEnd = ss - tab.length;
        } else if (evt.keyCode === 46 && t.value.slice(se, se + 4) === tab) {
          evt.preventDefault();
          t.value = t.value.slice(0, ss).concat(t.value.slice(ss + 4, t.value.length));
          return t.selectionStart = t.selectionEnd = ss;
        } else if (evt.keyCode === 37 && t.value.slice(ss - 4, ss) === tab) {
          evt.preventDefault();
          return t.selectionStart = t.selectionEnd = ss - 4;
        } else if (evt.keyCode === 39 && t.value.slice(ss, ss + 4) === tab) {
          evt.preventDefault();
          return t.selectionStart = t.selectionEnd = ss + 4;
        }
      },
      dirname: function(path) {
        var dirname;
        if (path.indexOf("/") === -1) {
          return "/";
        }
        dirname = path.replace(/\\/g, '/').replace(/\/[^\/]*\/?$/, '');
        if (dirname === "") {
          return "/";
        }
        return dirname;
      },
      escapeHtml: function(str) {
        return $("<div/>").text(str).html();
      },
      escapeQuotes: function(str) {
        return str.replace(/(['"])/, "\\$1");
      },
      startsWith: function(needle, haystack) {
        return haystack.length >= needle.length && haystack.substr(0, needle.length) === needle;
      }
    };
  }
}).call(this);
