import gleam/http.{Http}
import gleam/http/cookie.{Attributes}
import gleam/http/request
import gleam/http/response.{Response}
import gleam/option.{None, Option, Some}
import gleam/list
import gleam/string
import gleam/result
import howdy/context.{Context}
import howdy/context/user.{User}
import howdy/uuid
import howdy/authentication/ets
import howdy/authentication/session

const cookie_key = "howdy:user_session"

// 30 days
const long_timeout = 2592000

// 4 hours
const short_timeout = 14400

pub fn new() {
  new_with_config(CookieConfig(None, None, None))
}

pub fn new_with_config(cookie_config: CookieConfig) {
  ets.new(SessionFuncEts, [ets.Set, ets.Public, ets.NamedTable])
  case cookie_config.cookie {
    Some(cookie) -> {
      ets.insert(SessionFuncEts, #("cookie", cookie))
      Nil
    }
    None -> Nil
  }

  case cookie_config.data_storage {
    Some(storage) -> {
      ets.insert(SessionFuncEts, #("insert", storage.insert))
      ets.insert(SessionFuncEts, #("lookup", storage.lookup))
      ets.insert(SessionFuncEts, #("delete", storage.delete))
      Nil
    }

    None -> {
      session.new()
      Nil
    }
  }
}

pub fn authenticate_with_cookie(context: Context(a)) -> Result(User, Nil) {
  context
  |> get_cookie
  |> find_user
}

pub fn sign_in(
  username: String,
  password: String,
  remember_me: Bool,
  successful_response resp: Response(a),
  login_fn fun: fn(String, String) -> Result(List(#(String, String)), c),
) -> Result(Response(a), Nil) {
  let #(_, now, _) = now()
  let timeout = get_timeout(remember_me) + now

  case fun(username, password) {
    Ok(claims) -> {
      let id = get_unique_key()
      insert(id, username, timeout, claims)
      resp
      |> response.set_cookie(cookie_key, id, get_cookie_attributes())
      |> Ok
    }
    Error(_) -> Error(Nil)
  }
}

pub fn sign_out(context: Context(a), successful_response resp: Response(b)) {
  case get_cookie(context) {
    Ok(cookie) -> delete(cookie.1)
    Error(_) -> False
  }
  resp
  |> response.expire_cookie(cookie_key, get_cookie_attributes())
}

fn get_cookie(context: Context(a)) {
  request.get_cookies(context.request)
  |> list.find(fn(cookie) { cookie.0 == cookie_key })
}

fn find_user(cookie_result: Result(#(String, String), b)) {
  case cookie_result {
    Ok(cookie) -> get_user(cookie.1)
    Error(_) -> Error(Nil)
  }
}

fn get_user(data: String) {
  case lookup(data) {
    Ok(result) -> {
      let #(_key, name, timeout, claims) = result
      let #(_, now, _) = now()
      case timeout > now {
        True -> Ok(User(name, claims))
        False -> {
          delete(data)
          Error(Nil)
        }
      }
    }
    Error(_) -> Error(Nil)
  }
}

fn get_timeout(remember_me: Bool) {
  let #(_key, timeouts) =
    ets.lookup(SessionFuncEts, "timeouts")
    |> list.first
    |> result.unwrap(#("timeouts", Timeouts(long_timeout, short_timeout)))

  case remember_me {
    True -> timeouts.long
    False -> timeouts.short
  }
}

fn get_cookie_attributes() {
  let #(_key, cookie_attributes) =
    ets.lookup(SessionFuncEts, "cookie")
    |> list.first
    |> result.unwrap(#("cookie", cookie.defaults(Http)))

  cookie_attributes
  // let new_secs = 10 * 60
  // Attributes(
  //   max_age: Some(new_secs),
  //   domain: None,
  //   path: None,
  //   secure: False,
  //   http_only: False,
  //   same_site: None,
  // )
}

fn get_unique_key() {
  string.replace(uuid.v4_string(), "-", "")
}

external fn now() -> #(Int, Int, Int) =
  "erlang" "timestamp"

fn insert(
  key: String,
  username: String,
  expiry: Int,
  claims: List(#(String, String)),
) {
  let #(_key, inner_insert) =
    ets.lookup(SessionFuncEts, "insert")
    |> list.first
    |> result.unwrap(#("insert", session.insert))

  inner_insert(key, username, expiry, claims)
}

fn lookup(
  key: String,
) -> Result(#(String, String, Int, List(#(String, String))), Nil) {
  let #(_key, inner_lookup) =
    ets.lookup(SessionFuncEts, "lookup")
    |> list.first
    |> result.unwrap(#("lookup", session.lookup))

  inner_lookup(key)
}

fn delete(key: String) -> Bool {
  let #(_key, inner_delete) =
    ets.lookup(SessionFuncEts, "delete")
    |> list.first
    |> result.unwrap(#("delete", session.delete))

  inner_delete(key)
}

type SessionFuncEts {
  SessionFuncEts
}

pub type SessionStorage {
  SessionStorage(
    insert: fn(String, String, Int, List(#(String, String))) -> Bool,
    lookup: fn(String) ->
      Result(#(String, String, Int, List(#(String, String))), Nil),
    delete: fn(String) -> Bool,
  )
}

pub type Timeouts {
  Timeouts(short: Int, long: Int)
}

pub type CookieConfig {
  CookieConfig(
    cookie: Option(Attributes),
    session_storage: Option(SessionStorage),
    timeouts: Option(Timeouts),
  )
}
