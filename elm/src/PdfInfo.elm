module PdfInfo exposing (..)

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
    JD.map3 PdfInfo
        (JD.field "last_read" (JD.int |> JD.map Time.millisToPosix))
        (JD.field "filename" JD.string)
        (JD.maybe (JD.field "state" decodePersistentState))


decodePdfList : JD.Decoder (List PdfInfo)
decodePdfList =
    JD.field "pdfs" (JD.list decodePdfInfo)


type alias PersistentState =
    { pdfName : String
    , zoom : Float
    , page : Int
    , pageCount : Int
    }


decodePersistentState : JD.Decoder PersistentState
decodePersistentState =
    JD.map4 PersistentState
        (JD.field "pdf_name" JD.string)
        (JD.field "zoom" JD.float)
        (JD.field "page" JD.int)
        (JD.field "page_count" JD.int)


encodePersistentState : PersistentState -> JE.Value
encodePersistentState state =
    JE.object
        [ ( "pdf_name", JE.string state.pdfName )
        , ( "zoom", JE.float state.zoom )
        , ( "page", JE.int state.page )
        , ( "page_count", JE.int state.pageCount )
        ]
