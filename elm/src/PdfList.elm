module PdfList exposing (..)

import Calendar as CA
import DateTime as DT
import Element as E exposing (Element)
import Element.Background as EBg
import Element.Border as EB
import Element.Font as EF
import Element.Input as EI
import Json.Decode as JD
import Json.Encode as JE
import Time
import Util as U



{- #[derive(Serialize, Debug)]
   struct PdfList {
     pdfs: Vec<PdfInfo>,
   }

   #[derive(Serialize, Debug)]
   struct PdfInfo {
     last_read: Option<SystemTime>,
     filename: String,
   }
-}


type alias PdfList =
    { pdfs : List PdfInfo }


type alias PdfInfo =
    { lastRead : Time.Posix
    , fileName : String
    }


decodePdfInfo : JD.Decoder PdfInfo
decodePdfInfo =
    JD.map2 PdfInfo
        (JD.field "last_read" (JD.int |> JD.map Time.millisToPosix))
        (JD.field "filename" JD.string)


decodePdfList : JD.Decoder PdfList
decodePdfList =
    JD.map PdfList
        (JD.field "pdfs" (JD.list decodePdfInfo))


type Msg
    = Noop


view : PdfList -> Element msg
view pdfs =
    E.column [ E.width E.fill ] <|
        List.map
            (\pi ->
                E.row [ E.width E.fill ]
                    [ E.text pi.fileName
                    , E.text <| U.dateToString (CA.fromPosix pi.lastRead)
                    ]
            )
            pdfs.pdfs
