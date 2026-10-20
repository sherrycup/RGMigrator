"""Read top-level GDScript interfaces without interpreting game code.

The scanner balances brackets and quoted strings, so multiline signatures and
dictionary/array defaults stay intact. Inner classes and private helpers are
not presented as methods of the containing script.
"""

import re


def has_await(source):
    """Find an await keyword in code, excluding comments and quoted examples."""
    index = 0
    while index < len(source):
        char = source[index]
        if char == "#":
            end = source.find("\n", index)
            index = len(source) if end < 0 else end + 1
        elif char in "\"'":
            quote = char * 3 if source.startswith(char * 3, index) else char
            index += len(quote)
            while index < len(source):
                if source[index] == "\\":
                    index += 2
                elif source.startswith(quote, index):
                    index += len(quote)
                    break
                else:
                    index += 1
        elif char.isalpha() or char == "_":
            end = index + 1
            while end < len(source) and (source[end].isalnum() or source[end] == "_"):
                end += 1
            if source[index:end] == "await":
                return True
            index = end
        else:
            index += 1
    return False


def split_top_level(text, delimiter=","):
    parts, start, depth, quote, escaped = [], 0, 0, "", False
    for index, char in enumerate(text):
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = ""
        elif char in "\"'":
            quote = char
        elif char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        elif char == delimiter and depth == 0:
            parts.append(text[start:index].strip())
            start = index + 1
    if text[start:].strip():
        parts.append(text[start:].strip())
    return parts


def declaration(source, start):
    depth, quote, escaped = 0, "", False
    for index in range(start, len(source)):
        char = source[index]
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = ""
        elif char in "\"'":
            quote = char
        elif char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        elif char == ":" and depth == 0:
            return " ".join(line.strip() for line in source[start:index].splitlines())
    raise ValueError("Incomplete function declaration at " + str(start))


def parameters(text):
    result = []
    for item in split_top_level(text):
        default_parts = split_top_level(item, "=")
        annotation = default_parts[0]
        name, _, type_name = annotation.partition(":")
        result.append({"name": name.strip(), "type": type_name.strip() or "Variant", "default": "=".join(default_parts[1:]).strip() if len(default_parts) > 1 else None})
    return result


def interfaces(source):
    methods, callbacks = [], []
    declarations = list(re.finditer(r"(?m)^(?:static )?func ([A-Za-z_][A-Za-z0-9_]*)\(", source))
    for position, match in enumerate(declarations):
        name = match[1]
        if name.startswith("_") and name not in ("_init", "_ready", "_process", "_physics_process", "_input", "_unhandled_input", "_enter_tree", "_exit_tree", "_initialize", "_finalize", "_draw", "_gui_input", "_shortcut_input", "_unhandled_key_input", "_notification"):
            continue
        signature = declaration(source, match.start())
        # The last closing bracket belongs to the outer parameter list; return
        # types in this project do not contain function-type parentheses.
        opening, closing = signature.index("("), signature.rindex(")")
        return_type = signature[closing + 1:].removeprefix(" ->").strip() or "Variant"
        body = source[match.start():declarations[position + 1].start() if position + 1 < len(declarations) else len(source)]
        entry = {"name": name, "static": signature.startswith("static "), "signature": signature, "parameters": parameters(signature[opening + 1:closing]), "return": "void" if name == "_init" else return_type, "body": body}
        (callbacks if name.startswith("_") and name != "_init" else methods).append(entry)
    signals = []
    for match in re.finditer(r"(?m)^signal ([A-Za-z_][A-Za-z0-9_]*)(?:\(([^\n]*)\))?\s*$", source):
        signals.append({"name": match[1], "parameters": parameters(match[2] or "")})
    constants = [match[1] for match in re.finditer(r"(?m)^const ([A-Za-z_][A-Za-z0-9_]*)", source) if "preload(" not in source[match.start():source.find("\n", match.start())]]
    parent = re.search(r"(?m)^extends (.+)$", source)
    return {"methods": methods, "callbacks": callbacks, "signals": signals, "constants": constants, "parent": parent[1].strip() if parent else "RefCounted"}
