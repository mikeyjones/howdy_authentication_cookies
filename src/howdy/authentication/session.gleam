import gleam/list
import howdy/authentication/ets

pub type Session {
  Session
}

pub type TestSession {
  TestSession(
    insert: fn(String, String, Int, List(#(String, String))) -> Bool,
    lookup: fn(String) ->
      Result(#(String, String, Int, List(#(String, String))), Nil),
    delete: fn(String) -> Bool,
  )
}

pub fn new() {
  ets.new(Session, [ets.Set, ets.Public, ets.NamedTable])
}

pub fn insert(
  id: String,
  name: String,
  timeout: Int,
  claims: List(#(String, String)),
) {
  ets.insert(Session, #(id, name, timeout, claims))
}

pub fn lookup(id: String) {
  ets.lookup(Session, id)
  |> list.first
}

pub fn delete(id: String) {
  ets.delete(Session, id)
}
