module Query.Advanced exposing
    ( Query, perform, mapError
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

@docs Query, perform, mapError

---

**Most of the following functions are identical to those in [Query](Query).
Whenever the API is the same, the documentation will be blank.**

---


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


{-| An advanced Query that contains explicit error information.

All query functions that could fail will be required to give an `error`.

    queryUser : Int -> Query Model String User
    queryUser userId =
        Query.dictByKey "User not found" .users userId

You might want a custom type to keep track of errors:

    type QueryError
        = UserNotFound Int
        | PostNotFound Int
        | CommentNotFound Int

-}
type Query database error value
    = Query (database -> Result error value)


{-| Given a query and a database, perform the query.

    case Query.perform querySomeUser model of
        Ok user ->
            viewUser user

        Err message ->
            Element.text message

-}
perform : Query db x a -> db -> Result x a
perform (Query query_) =
    query_


{-| Map the error of a Query.
-}
mapError : (error -> x) -> Query db error a -> Query db x a
mapError fn (Query query_) =
    Query <|
        \db ->
            query_ db |> Result.mapError fn



--- BUILD


{-| -}
succeed : a -> Query db x a
succeed a =
    Query (\_ -> Ok a)


{-| A query that always fails with a given error.

For example, we could make a Query from a [RemoteData](https://package.elm-lang.org/packages/ohanhi/remotedata-http/latest/) like this:

    fromRemoteData : error -> RemoteData error a -> Query db error a
    fromRemoteData fallbackError remoteData =
        case remoteData of
            Success value ->
                Query.succeed value

            Failure e ->
                Query.fail e

            _ ->
                Query.fail fallbackError

-}
fail : error -> Query db error a
fail error =
    Query (\_ -> Err error)


{-| -}
identity : Query db x db
identity =
    Query Ok



--- HELPERS


{-| -}
map : (a -> b) -> Query db x a -> Query db x b
map func (Query query_) =
    Query <|
        \db ->
            query_ db |> Result.map func


{-| -}
map2 : (a -> b -> value) -> Query db x a -> Query db x b -> Query db x value
map2 func (Query queryA) (Query queryB) =
    Query <|
        \db ->
            case queryA db of
                Err x ->
                    Err x

                Ok a ->
                    queryB db |> Result.map (func a)


{-| -}
map3 : (a -> b -> c -> value) -> Query db x a -> Query db x b -> Query db x c -> Query db x value
map3 func a b c =
    map2 func a b |> map2 (|>) c


{-| -}
map4 :
    (a -> b -> c -> d -> value)
    -> Query db x a
    -> Query db x b
    -> Query db x c
    -> Query db x d
    -> Query db x value
map4 func a b c d =
    map3 func a b c |> map2 (|>) d


{-| -}
map5 :
    (a -> b -> c -> d -> e -> value)
    -> Query db x a
    -> Query db x b
    -> Query db x c
    -> Query db x d
    -> Query db x e
    -> Query db x value
map5 func a b c d e =
    map4 func a b c d |> map2 (|>) e


{-| -}
map6 :
    (a -> b -> c -> d -> e -> f -> value)
    -> Query db x a
    -> Query db x b
    -> Query db x c
    -> Query db x d
    -> Query db x e
    -> Query db x f
    -> Query db x value
map6 func a b c d e f =
    map5 func a b c d e |> map2 (|>) f


{-| -}
map7 :
    (a -> b -> c -> d -> e -> f -> g -> value)
    -> Query db x a
    -> Query db x b
    -> Query db x c
    -> Query db x d
    -> Query db x e
    -> Query db x f
    -> Query db x g
    -> Query db x value
map7 func a b c d e f g =
    map6 func a b c d e f |> map2 (|>) g


{-| -}
andMap : Query db x a -> Query db x (a -> b) -> Query db x b
andMap =
    map2 (|>)


{-| -}
andThen : (a -> Query db x b) -> Query db x a -> Query db x b
andThen func (Query query_) =
    Query <|
        \db ->
            case query_ db of
                Ok a ->
                    perform (func a) db

                Err x ->
                    Err x


{-| Just like [Query.orElse](Query#orElse), try a different query
in case of failure. Except we get to use the query's error to build
the new query.

For example, if we ask the name of an inexistent user, maybe we want to
default to an error message:

    queryUserName userId
        |> Query.orElse
            (\(NotFound id) ->
                Query.succeed <|
                    "The user "
                        ++ String.fromInt
                        ++ " doesn't exist."
            )

-}
orElse : (error -> Query db x a) -> Query db error a -> Query db x a
orElse func (Query query_) =
    Query <|
        \db ->
            case query_ db of
                Ok a ->
                    Ok a

                Err x ->
                    perform (func x) db



--- MAYBE


{-| Build a Query from a Maybe. The resulting
query will succeed only if the Maybe is `Just`.
The query fails with the given error if the Maybe is `Nothing`.
-}
fromMaybe : error -> Maybe a -> Query db error a
fromMaybe error =
    Maybe.map succeed >> Maybe.withDefault (fail error)



--- RESULT


{-| -}
fromResult : Result x a -> Query db x a
fromResult result =
    case result of
        Ok a ->
            succeed a

        Err x ->
            fail x



--- DICT


{-| Query a Dict's value using a key.
It takes an error in case the key is missing from the Dict.

    type alias Database =
        { movies : Dict Int Movie
        }

    type QueryError
        = MissingMovie Int

    queryMovieById moveId =
        Query.dictByKey (MissingMovie movieId) .movies movieId

-}
dictByKey : error -> (db -> Dict comparable a) -> comparable -> Query db error a
dictByKey error getDict key =
    identity
        |> andThen (fromMaybe error << Dict.get key << getDict)


{-| Query the first key of a Dict whose value passes the condition.
If no elements pass the condition, the query fails with the given error.
-}
dictKey : error -> (db -> Dict comparable a) -> (a -> Bool) -> Query db error comparable
dictKey error getDict condition =
    identity
        |> andThen (fromMaybe error << dictKeyHelper condition << getDict)


dictKeyHelper : (a -> Bool) -> Dict comparable a -> Maybe comparable
dictKeyHelper condition =
    Dict.foldl
        (\k v b ->
            case b of
                Just x ->
                    b

                Nothing ->
                    if condition v then
                        Just k

                    else
                        Nothing
        )
        Nothing


{-| -}
dictValues : (db -> Dict comparable a) -> (a -> Bool) -> Query db x (List a)
dictValues getDict condition =
    identity
        |> map (List.filter condition << Dict.values << getDict)


{-| -}
combineDict : Dict comparable (Query db x a) -> Query db x (Dict comparable a)
combineDict =
    Dict.foldl (map2 << Dict.insert) (succeed Dict.empty)


{-| -}
traverseDict : (comparable -> a -> Query db x b) -> Dict comparable a -> Query db x (Dict comparable b)
traverseDict map_ =
    Dict.map map_ >> combineDict



--- LIST


{-| Query the List's item at a specific index. If the index is out of bounds, fail with the given error.

    database =
        { superheroes = [ "Batman", "Spiderman" ]
        }

    querySuperhero index =
        Query.listByIndex (MissingSuperhero index) .superheroes index

    > Query.perform (querySuperhero 0) database
    Ok "Batman"

    > Query.perform (querySuperhero 1) database
    Ok "Spiderman"

    > Query.perform (querySuperhero 2) database
    MissingSuperhero 2

-}
listByIndex : error -> (db -> List a) -> Int -> Query db error a
listByIndex error getList index =
    identity
        |> andThen (fromMaybe error << listGetAt index << getList)


listGetAt : Int -> List a -> Maybe a
listGetAt index list_ =
    case ( list_, index ) of
        ( x :: xs, 0 ) ->
            Just x

        ( x :: xs, _ ) ->
            listGetAt (index - 1) xs

        ( [], _ ) ->
            Nothing


{-| -}
listItems : (db -> List a) -> (a -> Bool) -> Query db x (List a)
listItems getList condition =
    identity
        |> map (List.filter condition << getList)


{-| -}
listIndex : error -> (db -> List a) -> (a -> Bool) -> Query db error Int
listIndex error getList condition =
    identity
        |> andThen (fromMaybe error << getIndexFromList condition << getList)


getIndexFromList : (a -> Bool) -> List a -> Maybe Int
getIndexFromList =
    getIndexFromListHelp 0


getIndexFromListHelp : Int -> (a -> Bool) -> List a -> Maybe Int
getIndexFromListHelp index condition list =
    case list of
        x :: xs ->
            if condition x then
                Just index

            else
                getIndexFromListHelp (index + 1) condition xs

        [] ->
            Nothing


{-| -}
combineList : List (Query db x a) -> Query db x (List a)
combineList =
    List.foldr (map2 (::)) (succeed [])


{-| -}
traverseList :
    (a -> Query db x b)
    -> List a
    -> Query db x (List b)
traverseList makeQuery =
    List.map makeQuery >> combineList



--- ARRAY


{-| Similar to [listByIndex](Query.Advanced#listByIndex), query an element from an Array
by its index. If the index is out of bounds, the query fails with the given error.
-}
arrayByIndex : error -> (db -> Array a) -> Int -> Query db error a
arrayByIndex error getArray index =
    identity
        |> andThen (fromMaybe error << Array.get index << getArray)


{-| -}
arrayItems : (db -> Array a) -> (a -> Bool) -> Query db x (Array a)
arrayItems getArray condition =
    identity
        |> map (getArray >> Array.filter condition)


{-| -}
arrayIndex : error -> (db -> Array a) -> (a -> Bool) -> Query db error Int
arrayIndex error getArray condition =
    identity
        |> andThen (fromMaybe error << getIndexFromArray condition << getArray)


getIndexFromArray : (a -> Bool) -> Array a -> Maybe Int
getIndexFromArray condition array =
    Array.toList array |> getIndexFromList condition


{-| -}
combineArray : Array (Query db x a) -> Query db x (Array a)
combineArray =
    Array.foldl (map2 Array.push) (succeed Array.empty)


{-| -}
traverseArray : (a -> Query db x b) -> Array a -> Query db x (Array b)
traverseArray mapArray =
    Array.map mapArray >> combineArray



--- DEBUG


{-| -}
debug : (String -> Result x a -> Result x a) -> String -> Query db x a -> Query db x a
debug log tag (Query query_) =
    Query <|
        \db ->
            log tag (query_ db)
