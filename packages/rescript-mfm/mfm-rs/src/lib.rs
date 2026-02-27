mod parser;

use js_sys::{Array, Object, Reflect};
use parser::Node;
use wasm_bindgen::prelude::*;

// ============================================================
// JS object construction
// ============================================================

fn set_prop(obj: &Object, key: &str, val: &JsValue) {
    let _ = Reflect::set(obj, &JsValue::from_str(key), val);
}

fn make_props() -> Object {
    Object::new()
}

fn node_to_js(node: &Node) -> JsValue {
    let obj = Object::new();

    match node {
        Node::Text(text) => {
            set_prop(&obj, "type", &"text".into());
            let props = make_props();
            set_prop(&props, "text", &JsValue::from_str(text));
            set_prop(&obj, "props", &props.into());
        }
        Node::Bold(children) => {
            set_prop(&obj, "type", &"bold".into());
            set_prop(&obj, "children", &nodes_to_js(children));
        }
        Node::Italic(children) => {
            set_prop(&obj, "type", &"italic".into());
            set_prop(&obj, "children", &nodes_to_js(children));
        }
        Node::Strike(children) => {
            set_prop(&obj, "type", &"strike".into());
            set_prop(&obj, "children", &nodes_to_js(children));
        }
        Node::Small(children) => {
            set_prop(&obj, "type", &"small".into());
            set_prop(&obj, "children", &nodes_to_js(children));
        }
        Node::Center(children) => {
            set_prop(&obj, "type", &"center".into());
            set_prop(&obj, "children", &nodes_to_js(children));
        }
        Node::Plain(children) => {
            set_prop(&obj, "type", &"plain".into());
            set_prop(&obj, "children", &nodes_to_js(children));
        }
        Node::Quote(children) => {
            set_prop(&obj, "type", &"quote".into());
            set_prop(&obj, "children", &nodes_to_js(children));
        }
        Node::InlineCode(code) => {
            set_prop(&obj, "type", &"inlineCode".into());
            let props = make_props();
            set_prop(&props, "code", &JsValue::from_str(code));
            set_prop(&obj, "props", &props.into());
        }
        Node::BlockCode { code, lang } => {
            set_prop(&obj, "type", &"blockCode".into());
            let props = make_props();
            set_prop(&props, "code", &JsValue::from_str(code));
            match lang {
                Some(l) => set_prop(&props, "lang", &JsValue::from_str(l)),
                None => set_prop(&props, "lang", &JsValue::NULL),
            }
            set_prop(&obj, "props", &props.into());
        }
        Node::MathInline(formula) => {
            set_prop(&obj, "type", &"mathInline".into());
            let props = make_props();
            set_prop(&props, "formula", &JsValue::from_str(formula));
            set_prop(&obj, "props", &props.into());
        }
        Node::MathBlock(formula) => {
            set_prop(&obj, "type", &"mathBlock".into());
            let props = make_props();
            set_prop(&props, "formula", &JsValue::from_str(formula));
            set_prop(&obj, "props", &props.into());
        }
        Node::Mention { username, host } => {
            set_prop(&obj, "type", &"mention".into());
            let props = make_props();
            set_prop(&props, "username", &JsValue::from_str(username));
            match host {
                Some(h) => set_prop(&props, "host", &JsValue::from_str(h)),
                None => set_prop(&props, "host", &JsValue::NULL),
            }
            set_prop(&obj, "props", &props.into());
            // Mention also has children with the acct text
            let children = Array::new();
            let text_node = Object::new();
            set_prop(&text_node, "type", &"text".into());
            let text_props = make_props();
            let acct = match host {
                Some(h) => format!("@{}@{}", username, h),
                None => format!("@{}", username),
            };
            set_prop(&text_props, "text", &JsValue::from_str(&acct));
            set_prop(&text_node, "props", &text_props.into());
            children.push(&text_node.into());
            set_prop(&obj, "children", &children.into());
        }
        Node::Hashtag(tag) => {
            set_prop(&obj, "type", &"hashtag".into());
            let props = make_props();
            set_prop(&props, "hashtag", &JsValue::from_str(tag));
            set_prop(&obj, "props", &props.into());
        }
        Node::Url(url) => {
            set_prop(&obj, "type", &"url".into());
            let props = make_props();
            set_prop(&props, "url", &JsValue::from_str(url));
            set_prop(&obj, "props", &props.into());
        }
        Node::Link {
            url,
            children,
            silent,
        } => {
            set_prop(&obj, "type", &"link".into());
            let props = make_props();
            set_prop(&props, "url", &JsValue::from_str(url));
            set_prop(&props, "silent", &JsValue::from_bool(*silent));
            set_prop(&obj, "props", &props.into());
            set_prop(&obj, "children", &nodes_to_js(children));
        }
        Node::Fn {
            name,
            args,
            children,
        } => {
            set_prop(&obj, "type", &"fn".into());
            let props = make_props();
            set_prop(&props, "name", &JsValue::from_str(name));
            let args_obj = Object::new();
            for (k, v) in args {
                set_prop(&args_obj, k, &JsValue::from_str(v));
            }
            set_prop(&props, "args", &args_obj.into());
            set_prop(&obj, "props", &props.into());
            set_prop(&obj, "children", &nodes_to_js(children));
        }
        Node::EmojiCode(name) => {
            set_prop(&obj, "type", &"emojiCode".into());
            let props = make_props();
            set_prop(&props, "name", &JsValue::from_str(name));
            set_prop(&obj, "props", &props.into());
        }
        Node::UnicodeEmoji(emoji) => {
            set_prop(&obj, "type", &"unicodeEmoji".into());
            let props = make_props();
            set_prop(&props, "emoji", &JsValue::from_str(emoji));
            set_prop(&obj, "props", &props.into());
        }
        Node::Search(query) => {
            set_prop(&obj, "type", &"search".into());
            let props = make_props();
            set_prop(&props, "query", &JsValue::from_str(query));
            set_prop(&obj, "props", &props.into());
        }
    }

    obj.into()
}

fn nodes_to_js(nodes: &[Node]) -> JsValue {
    let arr = Array::new();
    for node in nodes {
        arr.push(&node_to_js(node));
    }
    arr.into()
}

// ============================================================
// WASM exports
// ============================================================

#[wasm_bindgen(start)]
fn init_panic_hook() {
    console_error_panic_hook::set_once();
}

#[wasm_bindgen]
pub fn parse(input: &str) -> JsValue {
    let mut p = parser::Parser::new(input, 20);
    nodes_to_js(&p.parse())
}

#[wasm_bindgen(js_name = "parseWithLimit")]
pub fn parse_with_limit(input: &str, nest_limit: u32) -> JsValue {
    let mut p = parser::Parser::new(input, nest_limit);
    nodes_to_js(&p.parse())
}

#[wasm_bindgen(js_name = "parseSimple")]
pub fn parse_simple(input: &str) -> JsValue {
    let mut p = parser::Parser::new(input, 20);
    nodes_to_js(&p.parse_simple())
}
