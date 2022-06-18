// pub type UserLookup {
//   UserLookup(key: String, name: String)
// }
// pub type TableTypes {
//   Set
//   OrderedSet
//   Bag
//   DuplicateBag
// }
// pub type AccessControls {
//   Public
//   Protected
//   Private
// }
pub type Options {
  Set
  OrderedSet
  Bag
  DuplicateBag
  Public
  Protected
  Private
  NamedTable
}

pub external type Identifier

pub external fn new(table: a, options: List(Options)) -> Identifier =
  "ets" "new"

pub external fn insert(table: a, tuple) -> Bool =
  "ets" "insert"

pub external fn lookup(table: a, id) -> List(b) =
  "ets" "lookup"

pub external fn delete(table: a, id) -> Bool =
  "ets" "delete"
