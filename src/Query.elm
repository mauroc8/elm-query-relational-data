module Query exposing
    ( Query, perform
    , dictByKey, listByIndex, arrayByIndex
    , dictValues, listItems, arrayItems
    , dictKey, listIndex, arrayIndex
    , map, map2, map3, andThen, orElse
    , map4, map5, map6, map7, andMap
    , fromMaybe, fromResult
    , combineList, traverseList
    , combineDict, traverseDict
    , combineArray, traverseArray
    , succeed, fail, identity
    , debug
    )

{-|

@docs Query, perform


# Query elements by id

Queries to fetch a single element from a collection.

@docs dictByKey, listByIndex, arrayByIndex


# Query elements with conditions

Queries to conditionally fetch elements.

@docs dictValues, listItems, arrayItems

Queries to get the id of an element that passes a condition.

@docs dictKey, listIndex, arrayIndex


# Transform, chain and combine queries

@docs map, map2, map3, andThen, orElse


## Additional mapping functions

@docs map4, map5, map6, map7, andMap


# More helpers

@docs fromMaybe, fromResult


## List

@docs combineList, traverseList


## Dict

@docs combineDict, traverseDict


## Array

@docs combineArray, traverseArray


# Fancy building blocks

@docs succeed, fail, identity


# Debug

@docs debug

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Query.Advanced
import Result


{-| A **query** describes how to get a _value_ from a _database_.
A database is expected to be a record with many Dicts and Lists, typically your model.

    type alias Model =
        { ... }

    querySomeUser : Query Model User

Unlike queries in [Query.Advanced](Query.Advanced), the queries in this module
do not keep track of errors.

-}
type alias Query database value =
    Query.Advanced.Query database () value


{-| Given a query and a database, perform the query.

    case Query.perform querySomeUser model of
        Just user ->
            viewUser user

        Nothing ->
            Element.text "The requested user doesn't exist!"

A query that fails gives no information on why it failed!

You can use [debug](Query#debug) to debug your queries,
or [Query.Advanced](Query.Advanced) to handle errors explicitly.

-}
perform : Query db a -> db -> Maybe a
perform query =
    Query.Advanced.perform query >> Result.toMaybe



--- BUILD


{-| A query that always succeeds with the given value.

This means that performimg such query always results in `Just` the given value.

The `succeed` function can be useful to combine query values with non-query values.
See [map3](Query#map3) for an example.

-}
succeed : a -> Query db a
succeed =
    Query.Advanced.succeed


{-| A query that always fails. For example, we could
make a Query from a [RemoteData](https://package.elm-lang.org/packages/ohanhi/remotedata-http/latest/) like this:

    fromRemoteData remoteData =
        case remoteData of
            Success value ->
                Query.succeed value

            _ ->
                Query.fail

-}
fail : Query db a
fail =
    Query.Advanced.fail ()


{-| A query that fetches the whole database.
Use it as a starting point to build more useful queries.

    type alias Model =
        { posts : Result Error (Dict Int Post)
        }

    queryPost : Int -> Query Model Post
    queryPost postId =
        Query.identity
            |> Query.andThen (Query.fromResult << .posts)
            |> Query.andThen (Query.fromMaybe << Dict.get postId)

-}
identity : Query db db
identity =
    Query.Advanced.identity



--- HELPERS


{-| Transform the value of a Query using a function.

    queryUserName : Int -> Query Model String
    queryUserName userId =
        queryUser userId
            |> Query.map (\user -> user.name)

-}
map : (a -> b) -> Query db a -> Query db b
map =
    Query.Advanced.map


{-| Combine two queries using a function.
If any of the queries fails, the combined query will also fail!

    userWithPostsQuery : Int -> Query Model ( User, List Post )
    userWithPostsQuery userId =
        Query.map2 Tuple.pair
            (userQuery userId)
            (userPostsQuery userId)

-}
map2 : (a -> b -> value) -> Query db a -> Query db b -> Query db value
map2 =
    Query.Advanced.map2


{-| Combine three queries using a function. Similar to [map2](Query#map2).

    type alias Post user =
        { author : user
        , title : String
        , content : String
        }

    queryUserOfPost : Post Int -> Query Model (Post User)
    queryUserOfPost post =
        Query.map3 Post
            (queryUser post.author)
            (Query.succeed post.title)
            (Query.succeed post.content)

-}
map3 : (a -> b -> c -> value) -> Query db a -> Query db b -> Query db c -> Query db value
map3 =
    Query.Advanced.map3


{-| -}
map4 :
    (a -> b -> c -> d -> value)
    -> Query db a
    -> Query db b
    -> Query db c
    -> Query db d
    -> Query db value
map4 =
    Query.Advanced.map4


{-| -}
map5 :
    (a -> b -> c -> d -> e -> value)
    -> Query db a
    -> Query db b
    -> Query db c
    -> Query db d
    -> Query db e
    -> Query db value
map5 =
    Query.Advanced.map5


{-| -}
map6 :
    (a -> b -> c -> d -> e -> f -> value)
    -> Query db a
    -> Query db b
    -> Query db c
    -> Query db d
    -> Query db e
    -> Query db f
    -> Query db value
map6 =
    Query.Advanced.map6


{-| -}
map7 :
    (a -> b -> c -> d -> e -> f -> g -> value)
    -> Query db a
    -> Query db b
    -> Query db c
    -> Query db d
    -> Query db e
    -> Query db f
    -> Query db g
    -> Query db value
map7 =
    Query.Advanced.map7


{-| -}
andMap : Query db a -> Query db (a -> b) -> Query db b
andMap =
    Query.Advanced.andMap


{-| Chain two queries together. For example, given the query defined in [map3](Query#map3),
we can build a query that fetches a post _and then_ fetches the user of that post.

    queryPost : Int -> Query Model (Post Int)
    queryPost =
        Query.dictByKey .posts

    queryPostWithUser : Int -> Query Model (Post User)
    queryPostWithUser postId =
        queryPost postId
            |> Query.andThen queryUserOfPost

-}
andThen : (a -> Query db b) -> Query db a -> Query db b
andThen =
    Query.Advanced.andThen


{-| Try a different query in case of failure. For example, to
query the posts of a user _or else_ query all posts, we can write:

    queryPostsOfUser userId
        |> Query.orElse (\_ -> queryAllPosts)

-}
orElse : (() -> Query db a) -> Query db a -> Query db a
orElse =
    Query.Advanced.orElse



--- MAYBE


{-| Build a Query from a Maybe. The resulting
query will succeed only if the Maybe is `Just`.
-}
fromMaybe : Maybe a -> Query db a
fromMaybe =
    Query.Advanced.fromMaybe ()



--- RESULT


{-| Build a Query from a Result. The resulting
query will succeed only if the Result is `Ok`.
-}
fromResult : Result x a -> Query db a
fromResult result =
    case result of
        Ok a ->
            succeed a

        Err _ ->
            fail



--- DICT


{-| Query a Dict's value using a key.
The first argument is a function that selects a Dict from the database.

    type alias Database =
        { movies : Dict Int Movie
        }

    queryMovieById moveId =
        Query.dictByKey .movies movieId

-}
dictByKey : (db -> Dict comparable a) -> comparable -> Query db a
dictByKey =
    Query.Advanced.dictByKey ()


{-| Query the first key of a Dict whose value matches the condition.

This can be used to query a user's id given their email:

    userIdQuery : String -> Query db Int
    userIdQuery email =
        Query.dictKey .users (\user -> user.email == email)

> **Note**: The search starts in the lower element.

-}
dictKey : (db -> Dict comparable a) -> (a -> Bool) -> Query db comparable
dictKey =
    Query.Advanced.dictKey ()


{-| Get all elements of a Dict that satisfy certain condition.

For example, to get all posts written by some user:

    userPostsQuery userId =
        Query.dictValues .posts
            (\post -> post.author == userId)

-}
dictValues : (db -> Dict comparable a) -> (a -> Bool) -> Query db (List a)
dictValues =
    Query.Advanced.dictValues


{-| Combine a Dict of Queries into a single query.
If any of those queries fail, the resulting query will fail.
-}
combineDict : Dict comparable (Query db a) -> Query db (Dict comparable a)
combineDict =
    Query.Advanced.combineDict


{-| Map each key-value pair of a Dict to a Query, and then combine the Dict
into a Query using [combineDict](Query#combineDict).
-}
traverseDict : (comparable -> a -> Query db b) -> Dict comparable a -> Query db (Dict comparable b)
traverseDict =
    Query.Advanced.traverseDict



--- LIST


{-| Query a List by its index. If the index is outside the range of the List, the query will fail.

    database =
        { superheroes = [ "Batman", "Spiderman" ]
        }

    querySuperhero index =
        Query.listByIndex .superheroes index

    > Query.perform (querySuperhero 0) database
    Just "Batman"

    > Query.perform (querySuperhero 1) database
    Just "Spiderman"

    > Query.perform (querySuperhero 2) database
    Nothing

-}
listByIndex : (db -> List a) -> Int -> Query db a
listByIndex =
    Query.Advanced.listByIndex ()


{-| Similar to [dictValues](Query#dictValues). Query the items of a List that pass
the condition.
-}
listItems : (db -> List a) -> (a -> Bool) -> Query db (List a)
listItems =
    Query.Advanced.listItems


{-| Query the index of the first element in the List that passes the condition.
-}
listIndex : (db -> List a) -> (a -> Bool) -> Query db Int
listIndex =
    Query.Advanced.listIndex ()


{-| Combines a list of queries into a single query.
If any of the list queries fail, the resulting query will fail.

    queryPosts : List Int -> Query Model (List Post)
    queryPosts idList =
        List.map queryPost idList
            |> Query.combineList

-}
combineList : List (Query db a) -> Query db (List a)
combineList =
    Query.Advanced.combineList


{-| Similar to [combineList](Query#combineList), it transforms
a List into a Query. The difference is that it maps the list
before doing it. This is what you need to do most of the times.

For example, we can rewrite the function we defined in [combineList](Query#combineList):

    queryPosts =
        Query.traverseList queryPost

-}
traverseList :
    (a -> Query db b)
    -> List a
    -> Query db (List b)
traverseList =
    Query.Advanced.traverseList



--- ARRAY


{-| Similar to [listByIndex](Query#listByIndex), query an element from an array
by its index.
-}
arrayByIndex : (db -> Array a) -> Int -> Query db a
arrayByIndex =
    Query.Advanced.arrayByIndex ()


{-| Similar to [dictValues](Query#dictValues). Query the items of an Array that pass
the condition.
-}
arrayItems : (db -> Array a) -> (a -> Bool) -> Query db (Array a)
arrayItems =
    Query.Advanced.arrayItems


{-| Query the index of the first element in the Array that passes the condition.
-}
arrayIndex : (db -> Array a) -> (a -> Bool) -> Query db Int
arrayIndex =
    Query.Advanced.arrayIndex ()


{-| See [combineList](Query#combineList).
-}
combineArray : Array (Query db a) -> Query db (Array a)
combineArray =
    Query.Advanced.combineArray


{-| See [traverseList](Query#traverseList).
-}
traverseArray : (a -> Query db b) -> Array a -> Query db (Array b)
traverseArray =
    Query.Advanced.traverseArray



--- DEBUG


{-| Pipeline friendly function to log the inner state of a query.
Useful when a query fails and you don't know why!

For example, if the following query fails, we can log the intermediate state
to know if the error is in the first query or not.

    Query.dictByKey .films filmId
        |> Query.debug Debug.log "Film"
        |> Query.andThen queryFilmActors

-}
debug : (String -> Maybe a -> Maybe a) -> String -> Query db a -> Query db a
debug log =
    Query.Advanced.debug
        (\tag result ->
            let
                _ =
                    log tag (Result.toMaybe result)
            in
            result
        )
