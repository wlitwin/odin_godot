extends Node

# A user-directed browser text field supports real paste inside cross-origin
# iframes without navigator.clipboard.readText or a cached engine clipboard.
const INSTALL := """
(() => {
    const api = {
        dialog: null,
        result: null,
        open(options) {
            if (this.dialog) return false;
            this.result = null;
            const dialog = document.createElement('dialog');
            dialog.id = 'dockyard-room-entry';
            dialog.style.cssText = 'width:min(26rem,80vw);padding:24px;border:2px solid #4ce4cf;border-radius:14px;background:#102631;color:#fff2d6;font:18px system-ui;';
            const form = document.createElement('form');
            const label = document.createElement('label');
            label.textContent = 'Room code';
            const input = document.createElement('input');
            input.type = 'text';
            input.id = 'dockyard-room-code';
            input.setAttribute('aria-label', 'Room code');
            input.autocomplete = 'off';
            input.spellcheck = false;
            input.setAttribute('autocapitalize', 'characters');
            input.maxLength = options.maxLength;
            input.value = options.value;
            input.readOnly = !!options.copy;
            input.style.cssText = 'box-sizing:border-box;display:block;width:100%;margin:12px 0;padding:12px;font:22px monospace;border:1px solid #4ce4cf;border-radius:6px;';
            label.appendChild(input);
            const hint = document.createElement('p');
            hint.textContent = options.copy ? 'Copy this code for your crewmate.' : 'Type the code, or paste with Cmd/Ctrl+V.';
            hint.style.fontSize = '14px';
            const use = document.createElement('button');
            use.type = 'submit'; use.textContent = options.copy ? 'Copy code' : 'Use code';
            const cancel = document.createElement('button');
            cancel.type = 'button'; cancel.textContent = options.copy ? 'Done' : 'Cancel';
            for (const button of [use, cancel]) button.style.cssText = 'padding:10px 16px;margin:4px 8px 0 0;font:16px system-ui;cursor:pointer;';
            const remove = () => {
                input.value = ''; dialog.remove();
                if (this.dialog === dialog) this.dialog = null;
            };
            const finish = (accepted) => {
                this.result = {accepted, value: accepted ? input.value : ''};
                dialog.close();
                remove();
            };
            form.addEventListener('submit', event => {
                event.preventDefault();
                if (!options.copy) {finish(true); return;}
                // A direct user gesture on a selected native input works even
                // when the iframe cannot use the asynchronous Clipboard API.
                input.focus(); input.select();
                let copied = false;
                try {copied = document.execCommand('copy');} catch (_) {}
                hint.textContent = copied ? 'Copied.' : 'Press Cmd/Ctrl+C to copy the selected code.';
            });
            cancel.addEventListener('click', () => finish(false));
            dialog.addEventListener('cancel', event => {event.preventDefault(); finish(false);});
            dialog.addEventListener('keydown', event => event.stopPropagation());
            dialog.addEventListener('close', () => {
                if (this.dialog !== dialog) return;
                remove();
                if (!this.result) this.result = {accepted:false,value:''};
            });
            form.append(label, hint, use, cancel); dialog.appendChild(form);
            document.body.appendChild(dialog); this.dialog = dialog;
            dialog.showModal(); input.focus(); input.select();
            return true;
        },
        take() {const result = this.result; this.result = null; return JSON.stringify(result);},
        destroy() {
            if (this.dialog) {
                const dialog = this.dialog; this.dialog = null;
                dialog.querySelector('input').value = ''; dialog.close(); dialog.remove();
            }
            this.result = null;
        }
    };
    window.dockyardTextEntry = api;
    return true;
})()
"""

var field: LineEdit
var active := false

func _ready() -> void:
	set_process(false)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(INSTALL, true)

func edit(target: LineEdit) -> void:
	if not OS.has_feature("web") or active or not target.editable:
		return
	var options := JSON.stringify({"value": target.text, "maxLength": 85})
	if bool(JavaScriptBridge.eval("window.dockyardTextEntry.open(%s)" % options, true)):
		field = target
		active = true
		set_process(true)

func copy_code(code: String) -> void:
	if not OS.has_feature("web") or active:
		return
	var options := JSON.stringify({"value": code, "maxLength": 85, "copy": true})
	if bool(JavaScriptBridge.eval("window.dockyardTextEntry.open(%s)" % options, true)):
		active = true
		set_process(true)

func _process(_delta: float) -> void:
	var reply: Variant = JSON.parse_string(str(JavaScriptBridge.eval("window.dockyardTextEntry.take()", true)))
	if not reply is Dictionary:
		return
	if is_instance_valid(field):
		if bool(reply.get("accepted", false)):
			var value := str(reply.get("value", "")).strip_edges()
			field.text = value.to_upper() if value.length() == 5 else value
			field.caret_column = field.text.length()
		field.release_focus()
	field = null
	active = false
	set_process(false)

func _exit_tree() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.dockyardTextEntry?.destroy()", true)
	field = null
	active = false
