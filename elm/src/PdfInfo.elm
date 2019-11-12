module PdfInfo exposing (..)

import Json.Decode as JD
import Json.Encode as JE
import Time


type alias PdfInfo =
    { lastRead : Time.Posix
    , fileName : String
    }


decodePdfInfo : JD.Decoder PdfInfo
decodePdfInfo =
    JD.map2 PdfInfo
        (JD.field "last_read" (JD.int |> JD.map Time.millisToPosix))
        (JD.field "filename" JD.string)


decodePdfList : JD.Decoder (List PdfInfo)
decodePdfList =
    JD.field "pdfs" (JD.list decodePdfInfo)
