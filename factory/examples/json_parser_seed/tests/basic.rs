use json_parser::{parse, Value};

#[test]
fn null() { assert_eq!(parse("null").unwrap(), Value::Null); }

#[test]
fn number() { assert_eq!(parse("42").unwrap(), Value::Number(42.0)); }

#[test]
fn string() { assert_eq!(parse("\"hi\"").unwrap(), Value::String("hi".into())); }

#[test]
fn array() {
    assert_eq!(parse("[1, 2]").unwrap(),
        Value::Array(vec![Value::Number(1.0), Value::Number(2.0)]));
}
