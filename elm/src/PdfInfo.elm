module PdfInfo exposing (..)

import Dict exposing (Dict)
import Json.Decode as JD
import Json.Encode as JE
import Time


type alias PdfInfo =
    { lastRead : Time.Posix
    , fileName : String
    , state : Maybe PersistentState
    }


decodePdfInfo : JD.Decoder PdfInfo
decodePdfInfo =
    (JD.maybe <| JD.field "state" decodePersistentState)
        |> JD.andThen
            (\mbps ->
                JD.map3 PdfInfo
                    (mbps
                        |> Maybe.map (\ps -> JD.succeed ps.lastRead)
                        |> Maybe.withDefault (JD.field "last_read" (JD.int |> JD.map Time.millisToPosix))
                    )
                    (JD.field "filename" JD.string)
                    (JD.succeed mbps)
            )


decodePdfList : JD.Decoder (List PdfInfo)
decodePdfList =
    JD.field "pdfs" (JD.list decodePdfInfo)


type alias PersistentState =
    { pdfName : String
    , zoom : Float
    , page : Int
    , pageCount : Int
    , lastRead : Time.Posix
    }


decodePersistentState : JD.Decoder PersistentState
decodePersistentState =
    JD.map5 PersistentState
        (JD.field "pdf_name" JD.string)
        (JD.field "zoom" JD.float)
        (JD.field "page" JD.int)
        (JD.field "page_count" JD.int)
        (JD.field "last_read" (JD.int |> JD.map Time.millisToPosix))


encodePersistentState : PersistentState -> JE.Value
encodePersistentState state =
    JE.object
        [ ( "pdf_name", JE.string state.pdfName )
        , ( "zoom", JE.float state.zoom )
        , ( "page", JE.int state.page )
        , ( "page_count", JE.int state.pageCount )
        , ( "last_read", JE.int (Time.posixToMillis state.lastRead) )
        ]


type alias PdfNotes =
    { pdfName : String
    , notes : String
    , pageNotes : Dict Int String
    }


test : PdfNotes
test =
    { pdfName = "test"
    , notes = "test"
    , pageNotes = Dict.fromList [ ( 1, "test" ), ( 2, "test" ), ( 3, "test" ), ( 4, "test" ) ]
    }


decodePdfNotes : JD.Decoder PdfNotes
decodePdfNotes =
    JD.map3 PdfNotes
        (JD.field "pdf_name" JD.string)
        (JD.field "notes" JD.string)
        (JD.field "page_notes"
            (JD.list (JD.list JD.string)
                |> JD.andThen
                    (\lst ->
                        List.foldl
                            (\elt out ->
                                out
                                    |> Maybe.andThen
                                        (\listSoFar ->
                                            case elt of
                                                [ key, val ] ->
                                                    String.toInt key
                                                        |> Maybe.map
                                                            (\k -> ( k, val ) :: listSoFar)

                                                _ ->
                                                    Nothing
                                        )
                            )
                            (Just [])
                            lst
                            |> Maybe.map Dict.fromList
                            |> Maybe.map JD.succeed
                            |> Maybe.withDefault (JD.fail "failed to parse page notes")
                    )
            )
        )


encodePdfNotes : PdfNotes -> JE.Value
encodePdfNotes pn =
    JE.object
        [ ( "pdf_name", JE.string pn.pdfName )
        , ( "notes", JE.string pn.notes )
        , ( "page_notes"
          , JE.list
                (\( i, v ) -> JE.list JE.string [ String.fromInt i, v ])
                (Dict.toList pn.pageNotes)
          )
        ]
