unless window.Util?

    window.Util =

        # Default options
        # ---------------
        defaults:

            # What to insert when pressing `<Tab>`. (Used in the checkTab
            # method.)
            tab: "    "

        # ### basename
        #
        # Returns the filename component of the path
        #
        #     version: 1008.1718
        #     discuss at: http://phpjs.org/functions/basename
        #     +   original by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
        #     +   improved by: Ash Searle (http://hexmen.com/blog/)
        #     +   improved by: Lincoln Ramsay
        #     +   improved by: djmix
        #
        # Examples:
        #
        #     basename('/www/site/home.htm', '.htm');
        #     => 'home'
        #
        #     basename('ecra.php?p=1')
        #     => 'ecra.php?p=1'
        basename: (path, suffix) ->
            b = path.replace /^.*[\/\\]/g, ''
            if typeof(suffix) == 'string' && b.substr(b.length-suffix.length) == suffix
                b = b.substr 0, b.length-suffix.length
            return b

        # ### checkTab
        checkTab: (evt) ->
            if evt.metaKey then return

            tab = @defaults.tab
            t = evt.target
            ss = t.selectionStart
            se = t.selectionEnd

            # Tab key - insert tab expansion
            if evt.keyCode == 9

                evt.preventDefault()

                # Special case of multi line selection
                if (ss != se && t.value.slice(ss,se).indexOf("\n") != -1)

                    # In case selection was not of entire lines (e.g. selection
                    # begins in the middle of a line) we ought to tab at the
                    # beginning as well as at the start of every following line.
                    pre  = t.value.slice 0, ss
                    sel  = t.value.slice(ss,se).replace /\n/g, "\n#{tab}"
                    post = t.value.slice(se,t.value.length)
                    t.value = pre.concat(tab).concat(sel).concat(post)

                    t.selectionStart = ss + tab.length
                    t.selectionEnd   = se + tab.length

                # "Normal" case (no selection or selection on one line only)
                else
                    t.value  = t.value.slice(0,ss).concat(tab).concat(t.value.slice(ss,t.value.length))

                    if (ss == se)
                        t.selectionStart = t.selectionEnd = ss + tab.length
                    else
                        t.selectionStart = ss + tab.length
                        t.selectionEnd   = se + tab.length

            # Backspace key - delete preceding tab expansion, if exists
            else if evt.keyCode==8 && t.value.slice(ss - 4,ss) == tab
                evt.preventDefault()

                t.value = t.value.slice(0,ss - 4).concat(t.value.slice(ss,t.value.length));
                t.selectionStart  = t.selectionEnd = ss - tab.length

            # Delete key - delete following tab expansion, if exists
            else if evt.keyCode==46 && t.value.slice(se,se + 4) == tab
                evt.preventDefault()

                t.value = t.value.slice(0,ss).concat(t.value.slice(ss + 4,t.value.length))
                t.selectionStart = t.selectionEnd = ss

            # Left/right arrow keys - move across the tab in one go
            else if evt.keyCode == 37 && t.value.slice(ss - 4,ss) == tab
                evt.preventDefault(); t.selectionStart = t.selectionEnd = ss - 4

            else if (evt.keyCode == 39 && t.value.slice(ss,ss + 4) == tab)
                evt.preventDefault(); t.selectionStart = t.selectionEnd = ss + 4

        # Returns the directory name component of the path
        #
        # version: 1102.614
        # discuss at: http://phpjs.org/functions/dirname
        # +   original by: Ozh
        # +   improved by: XoraX (http://www.xorax.info)
        # *     example 1: dirname('/etc/passwd');
        # *     returns 1: '/etc'
        # *     example 2: dirname('c:/Temp/x');
        # *     returns 2: 'c:/Temp'
        # *     example 3: dirname('/dir/test/');
        # *     returns 3: '/dir'

        dirname: (path) ->

            return "/" if path.indexOf("/") == -1

            dirname = path.replace(/\\/g, '/').replace(/\/[^\/]*\/?$/, '')

            return "/" if dirname == ""
            return dirname

        escapeHtml: (str) -> return $("<div/>").text(str).html()

        escapeQuotes: (str) -> return str.replace /(['"])/, "\\$1"

        # Check whether a string starts with another string
        startsWith: (needle, haystack) ->
            return haystack.length >= needle.length &&
            haystack.substr(0, needle.length) == needle
