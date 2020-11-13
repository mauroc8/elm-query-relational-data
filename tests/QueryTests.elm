module QueryTests exposing (..)

import Dict exposing (Dict)
import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Query.Advanced as Query
import Test exposing (Test, describe, fuzz, test)


type alias Model =
    { users : Dict Int User
    , posts : Dict Int (Post Int)
    , comments : Dict Int (Comment Int)
    }


type alias User =
    { name : String
    }


type alias Post user =
    { user : user
    , title : String
    , content : String
    }


type alias Comment user =
    { user : user
    , post : Int
    , comment : String
    }


suite : Test
suite =
    describe "The Query module"
        [ describe "Query.succeed"
            [ fuzz Fuzz.int "performs to Just the given value" <|
                \randomInt ->
                    Query.perform (Query.succeed randomInt) ()
                        |> Expect.equal (Ok randomInt)
            ]
        , describe "Query.fail"
            [ test "performs to Nothing" <|
                \_ ->
                    Query.perform (Query.fail ()) ()
                        |> Expect.equal (Err ())
            ]
        , describe "Query.identity"
            [ fuzz Fuzz.int "performs to Just the given database" <|
                \randomInt ->
                    Query.perform Query.identity randomInt
                        |> Expect.equal (Ok randomInt)
            ]
        , describe "Query.map"
            [ fuzz Fuzz.int "doesn't alter the query when mapping with Basics.identity" <|
                \randomInt ->
                    Query.perform (Query.map identity <| Query.succeed randomInt) ()
                        |> Expect.equal (Query.perform (Query.succeed randomInt) ())
            , fuzz Fuzz.int "applies the given function to the result" <|
                \randomInt ->
                    Query.perform (Query.map (\x -> x * 2) <| Query.succeed randomInt) ()
                        |> Expect.equal (Ok <| randomInt * 2)
            ]

        --- This is when I skip the easy functions and start testing the more hairy stuff
        , describe "Query.traverseList"
            [ test "doesn't change the list's order" (Debug.todo "Finish tests")
            ]
        ]
