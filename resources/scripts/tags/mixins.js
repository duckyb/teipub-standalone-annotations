function Clipboard() {
    this.data = null;

    this.copy = function(model) {
        console.log("Copied to clipboard: %o", model);
        this.data = model;
    }

    this.paste = function() {
        console.log("Paste from clipboard: %o", this.data);
        return this.data;
    }
}
function Mixin(app) {
    this.app = app;

    this.indentString = '    ';

    this.clipboard = new Clipboard();

    var replaceChars = {
        '"': '&quot;',
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;'
    };

    this.escape = function(code) {
        var regex = new RegExp(Object.keys(replaceChars).join("|"), "g");
        return code.replace(regex, function(match) {
            return replaceChars[match];
        });
    }

    this.updateTag = function(name) {
        var data = [];
        this.forEachTag(name, function(tag) {
            data.push(tag.getData());
        });
        return data;
    }

    this.forEachTag = function(name, callback) {
        if (this.tags && this.tags[name]) {
            if (this.tags[name].length) {
                this.tags[name].forEach(function(tag) {
                    callback(tag);
                });
            } else {
                callback(this.tags[name]);
            }
        }
    }

    this.serializeTag = function(name, indent) {
        indent = indent || '';
        var xml = "";
        this.forEachTag(name, function(tag) {
            xml += tag.serialize(indent);
        });
        return xml;
    }

    this.moveModelDown = function(item) {
        var index = this.models.indexOf(item);
        if (index == this.models.length - 1) {
            return;
        }
        this.models = this.updateTag('model');
        var m = [];
        for (var i = 0; i < this.models.length; i++) {
            if (i == index) {
                m.push(this.models[i + 1]);
                m.push(this.models[i]);
                i++;
            } else {
                m.push(this.models[i]);
            }
        }
        this.models = m;
        this.update();
    }

    this.moveModelUp = function(item) {
        var index = this.models.indexOf(item);
        if (index == 0) {
            return;
        }
        this.models = this.updateTag('model');
        var m = [];
        for (var i = 0; i < this.models.length; i++) {
            if (i == index - 1) {
                m.push(this.models[index]);
                m.push(this.models[i]);
            } else if (i != index){
                m.push(this.models[i]);
            }
        }
        this.models = m;
        this.update();
    }
}
