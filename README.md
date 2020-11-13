# Query relational data

A **Query** represents instructions on how to query a value from a _relational database_.
The "database" is tipically your model.

If you haven't, check out [this excelent talk by Richard Feldman on Immutable Relational Data](https://www.youtube.com/watch?v=28OdemxhfbU).

Let's consider this "database":

    type alias Model =
        { users : Dict Int User
        , posts : Dict Int Post
        , comments : Dict Int Post
        }
    
    type alias User =
        { name : String }
    
    type alias Post =
        { author : Int, title : String, content : String }
    
    type alias Comment =
        { author : Int, post : Int, content : String }

We can build a query to fetch an user:

    queryUser : Int -> Query Model User
    queryUser userId =
        Query.dictByKey .users userId

We can then [perform](Query#perform) the query:

    Query.perform (queryUser 1) model
    > Just { name = "John" }

    Query.perform (queryUser 124) model
    > Nothing

> **Note:** You can get a `Result` when you *perform* queries if you use the [Query.Advanced](Query.Advanced) module instead.

## Combining queries

If we need a user *and* their posts, we can combine the queries!

    queryUserPosts : Int -> Query Model (List Post)
    queryUserPosts userId =
        Query.dictValues .posts (\post -> post.author == userId)


    userWithPostsQuery : Int -> Query Model ( User, List Post )
    userWithPostsQuery userId =
        Query.map2 Tuple.pair
            (queryUser userId)
            (queryUserPosts userId)

## Altering the shape of your data

Queries are also useful to "denormalize" data. For example, to view a post we may need its author and all its comments:

    type alias PostView =
        { author : User
        , title : String
        , content : String
        , comments : List ( User, String )
        }


We can't save `PostView`'s directly in our model, but we can write a query to get a PostView!

    queryPostView : Int -> Query Model PostView
    queryPostView postId =
        Query.dictByKey .posts postId
            |> Query.andThen (queryPostViewHelp postId)
    

    queryPostViewHelp : Int -> Post -> Query Model PostView
    queryPostViewHelp postId post =
        Query.map4 PostView
            (Query.dictByKey .users post.user)
            (Query.succeed post.title)
            (Query.succeed post.content)
            (queryPostComments postId)
    

    queryPostComments : Int -> Query Model (List CommentView)
    queryPostComments postId =
        Query.dictValues .comments (\c -> c.post == postId)
            |> Query.andThen
                (Query.traverseList queryCommentView)


    queryCommentView : Comment -> Query Model CommentView
    queryCommentView comment =
        Query.map2 Tuple.pair
            (Query.dictByKey .users comment.author)
            (Query.succeed comment.content)


That's all there is to is!

## Overview

The [Query](Query#Query) type is just a wrapper around a function `db -> Result x a`. That means you can go a long way using only Maybe/Result functions (and passing your Dicts everytime)!

This package provides the sole advantage of having helpers for common situations when dealing with relational data:

- Query a Dict by key ([dictByKey](Query#dictByKey)).
- Query a List or Array by index ([listByIndex](Query#listByIndex) and [arrayByIndex](Query#arrayByIndex)).
- Query a Dict's key (get the id of the user whose email is X) ([dictKey](Query#dictKey)).
- Get all the values from a Dict (or List) that pass some condition ([dictValues](Query#dictValues), [listItems](Query#listItems) and [arrayItems](Query#arrayItems)).
- Make a query for each item in a List ([traverseList](Query#traverseList)).


The [Query.Advanced](Query.Advanced) module has the same API as the [Query](Query) module, except it has explicit error information. This allows [Query.Advanced.perform](Query.Advanced#perform) to return a Result instead of a Maybe. This also means that every query that could fail will require the `error` as an extra argument.
