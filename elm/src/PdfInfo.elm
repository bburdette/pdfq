module PdfInfo exposing (..)

import Json.Decode as JD
import Json.Encode as JE
import Time


type LastState
    = LsViewer String
    | LsList


encodeLastState : LastState -> JE.Value
encodeLastState ls =
    case ls of
        LsViewer pdfn ->
            JE.object
                [ ( "state", JE.string "viewer" )
                , ( "pdfname", JE.string pdfn )
                ]

        LsList ->
            JE.object
                [ ( "state", JE.string "list" )
                ]


decodeLastState : JD.Decoder LastState
decodeLastState =
    JD.field "state" JD.string
        |> JD.andThen
            (\state ->
                case state of
                    "viewer" ->
                        JD.map LsViewer
                            (JD.field "pdfname" JD.string)

                    "list" ->
                        JD.succeed LsList

                    _ ->
                        JD.fail <| "unknown state type: " ++ state
            )


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
    , notesWidth : Int
    }


decodePersistentState : JD.Decoder PersistentState
decodePersistentState =
    JD.map6 PersistentState
        (JD.field "pdf_name" JD.string)
        (JD.field "zoom" JD.float)
        (JD.field "page" JD.int)
        (JD.field "page_count" JD.int)
        (JD.field "last_read" (JD.int |> JD.map Time.millisToPosix))
        (JD.maybe (JD.field "notesWidth" JD.int)
            |> JD.map (Maybe.withDefault 400)
        )


encodePersistentState : PersistentState -> JE.Value
encodePersistentState state =
    JE.object
        [ ( "pdf_name", JE.string state.pdfName )
        , ( "zoom", JE.float state.zoom )
        , ( "page", JE.int state.page )
        , ( "page_count", JE.int state.pageCount )
        , ( "last_read", JE.int (Time.posixToMillis state.lastRead) )
        , ( "notesWidth", JE.int state.notesWidth )
        ]


type alias PdfNotes =
    { pdfName : String
    , notes : String
    }


decodePdfNotes : JD.Decoder PdfNotes
decodePdfNotes =
    JD.map2 PdfNotes
        (JD.field "pdf_name" JD.string)
        (JD.field "notes" JD.string)


encodePdfNotes : PdfNotes -> JE.Value
encodePdfNotes pn =
    JE.object
        [ ( "pdf_name", JE.string pn.pdfName )
        , ( "notes", JE.string pn.notes )
        ]


type alias PdfOpened =
    { pdfName : String
    , pdfDoc : String
    , now : Time.Posix
    }


encodePdfOpened : PdfOpened -> JE.Value
encodePdfOpened po =
    JE.object
        [ ( "pdf_name", JE.string po.pdfName )
        , ( "pdf_string", JE.string po.pdfDoc )
        ]


type alias GetPdf =
    { pdfName : String
    , pdfUrl : String
    }


encodeGetPdf : GetPdf -> JE.Value
encodeGetPdf gp =
    JE.object
        [ ( "pdf_name", JE.string gp.pdfName )
        , ( "pdf_url", JE.string gp.pdfUrl )
        ]
