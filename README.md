# howdy_authentication_cookies

[![Package Version](https://img.shields.io/hexpm/v/howdy_authentication_cookies)](https://hex.pm/packages/howdy_authentication_cookies)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/howdy_authentication_cookies/)

Cookie authentication library for the [Howdy](https://github.com/mikeyjones/howdy) Web Server, using ETS as session storage. 

## Quick start

```gleam
import gleam/erlang
import gleam/result
import gleam/string
import howdy/server
import howdy/context.{Context}
import howdy/context/user
import howdy/router.{Get, Post, RouterMap, RouterMapWithFilters}
import howdy/response
import howdy/filter
import howdy/authentication/cookie

pub fn main() {
  let routes =
    RouterMap(
      "/",
      routes: [
        Get("/", fn(_) { response.of_string("hello from root") }),
        Post("/signin", do_sign_in),
        Post(
          "/signout",
          fn(context) {
            cookie.sign_out(context, response.of_string("signed out"))
          },
        ),
        RouterMapWithFilters(
          "/secret",
          filters: [filter.authenticate(_, cookie.authenticate_with_cookie)],
          routes: [Get("/", get_secret_page)],
        ),
      ],
    )

  cookie.new()
  assert Ok(_) = server.start(routes)
  erlang.sleep_forever()
}

fn get_secret_page(context: Context(a)) {
  let email =
    context.user
    |> user.get_claim("email")
    |> result.unwrap("No Email")

  response.of_string(string.concat(["Email: ", email]))
}

fn do_sign_in(_context: Context(a)) {
  case cookie.sign_in(
    "username",
    "password",
    True,
    response.of_string("signed in!"),
    validate_user,
  ) {
    Ok(resp) -> resp
    Error(_) -> response.of_internal_error("failed to sign you in!")
  }
}

fn validate_user(
  _username: String,
  _password: String,
) -> Result(List(#(String, String)), Nil) {
  // TODO: Get the claims from somewhere, database maybe?
  Ok([#("email", "test@email.com")])
}
```

## Installation

If available on Hex this package can be added to your Gleam project:

```sh
gleam add howdy_authentication_cookies
```

and its documentation can be found at <https://hexdocs.pm/howdy_authentication_cookies>.


## Configuration

There are several configuration options that allows you to control
the cookie authentication procesess better. The default configuration
is great for getting started, but is not advised for production, and 
you should set stronger cookie attributes to prevent unauthorized access 
to you cookies.

Calling ```cookie.new()``` sets the authentication library to its defaults. 

### Setting Cookie Attributes

You can modify the attributes of the cookies with the following:

```gleam
cookie.new_with_config(
    CookieConfig(
        Some(Attributes(
            max_age: None,
            domain: None,
            path: None,
            secure: False,
            http_only: False,
            same_site: None,
        )),
        None,
        None))
```

### Setting a custom storage method:

In order to change the default session storage of ETS, you can override
3 functions. This would allow you to use a database, reddis or a shared
implitmention that multiple servers can use.

You will need to create 3 functions with the following signitures:

```gleam
// Insert (unique_key, username, timeout_in_seconds, claims)
fn(String, String, Int, List(#(String, String))) -> Bool, 

// Lookup input of (unique_key) returns a result of #(unique_key, username, timeout_in_seconds, claims) 
fn(String) -> Result(#(String, String, Int, List(#(String, String))), Nil),

// Delete (unique_key)
fn(String) -> Bool,
```

#### Example:

```gleam
fn insert(key, user, timeout, claims) {
    False
} 

fn lookup(key) {
    Error(Nil)
}

fn delete(key) {
    False
}

cookie.new_with_config(
    CookieConfig(
        None,
        Some(
            DataStorage(
                insert, 
                lookup, 
                delete
            )
        ),
        None))
```

### Config session timeout

By default, if `remember me` is set to `False`, the session will last 4 hours, if it is set to `True` it will last for 30 days. You can change these defaults with the the foolowing:

```gleam
cookie.new_with_config(
    CookieConfig(
        None,
        None,
        Some(
            Timeouts(
                long: 126144000, // 4 years
                short: 10 // 10 seconds
            )
        )
    )
)
```