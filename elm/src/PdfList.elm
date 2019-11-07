module PdfList exposing (PdfInfo, PdfList)

import Json.Decode as JD
import Json.Encode as JE
import Time



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
